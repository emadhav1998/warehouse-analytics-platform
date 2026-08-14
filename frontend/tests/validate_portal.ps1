$ErrorActionPreference = "Stop"

$frontendRoot = Split-Path -Parent $PSScriptRoot
$htmlFiles = Get-ChildItem -Path $frontendRoot -Recurse -Filter "*.html"

foreach ($file in $htmlFiles) {
    $html = Get-Content -Raw -LiteralPath $file.FullName
    if ($html -notmatch '<html lang="en">') { throw "$($file.Name) is missing a language declaration." }
    if ($html -notmatch 'name="viewport"') { throw "$($file.Name) is missing a viewport declaration." }
    if ($html -notmatch 'id="main-content"') { throw "$($file.Name) is missing the main content landmark." }
    if ($html -notmatch 'aria-label="Primary navigation"') { throw "$($file.Name) is missing labelled navigation." }

    [regex]::Matches($html, '(?:href|src)="([^"#]+)"') | ForEach-Object {
        $reference = $_.Groups[1].Value
        if ($reference -match '^(https?:|mailto:|data:)') { return }
        $target = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $reference))
        if (-not (Test-Path -LiteralPath $target)) { throw "$($file.Name) references missing file: $reference" }
    }
    Write-Output "PASS: $($file.Name) accessibility landmarks and local references"
}

$dictionaryScript = Get-Content -Raw -LiteralPath (Join-Path $frontendRoot "js\data-dictionary.js")
$catalogHtml = Get-Content -Raw -LiteralPath (Join-Path $frontendRoot "pages\kpi-catalog.html")
$dictionaryHtml = Get-Content -Raw -LiteralPath (Join-Path $frontendRoot "pages\data-dictionary.html")
if ($catalogHtml -notmatch 'id="catalogSearch"' -or $catalogHtml -notmatch 'id="catalogDomain"') { throw "KPI Catalog requires search and domain filters." }
if ($dictionaryHtml -notmatch 'id="dictionarySearch"' -or $dictionaryHtml -notmatch 'id="dictionaryKind"') { throw "Data Dictionary requires search and table-type filters." }
Write-Output "PASS: both reference pages expose search and filter controls"

$martModels = Get-ChildItem -Path (Join-Path (Split-Path -Parent $frontendRoot) "dbt_warehouse\models\marts") -File -Filter "*.sql"
$martModels += Get-ChildItem -Path (Join-Path (Split-Path -Parent $frontendRoot) "dbt_warehouse\models\marts\aggregations") -File -Filter "*.sql"
foreach ($model in $martModels) {
    if ($dictionaryScript -notmatch [regex]::Escape("name: '$($model.BaseName)'")) {
        throw "Data dictionary is missing model: $($model.BaseName)"
    }
}
Write-Output "PASS: data dictionary covers $($martModels.Count) mart models"

$appScript = Get-Content -Raw -LiteralPath (Join-Path $frontendRoot "js\app.js")
if ($appScript -match '\.innerHTML\s*=') { throw "app.js must not inject API data through innerHTML." }
Write-Output "PASS: live API rendering avoids innerHTML injection"

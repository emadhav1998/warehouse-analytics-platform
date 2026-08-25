$ErrorActionPreference = "Stop"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$powerBiRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $powerBiRoot
$reportPath = Join-Path $powerBiRoot "reports\dashboard_pages.json"
$themePath = Join-Path $powerBiRoot "theme\warehouse_analytics_theme.json"
$refreshPath = Join-Path $powerBiRoot "config\refresh_schedule.json"
$optimizationPath = Join-Path $powerBiRoot "config\model_optimization.json"
$apiKpiPath = Join-Path $repoRoot "backend\app\routers\kpis.py"
$rlsPath = Join-Path $powerBiRoot "rls\warehouse_rls.dax"
$rolesPath = Join-Path $powerBiRoot "rls\roles.json"

$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
$theme = Get-Content -Raw -LiteralPath $themePath | ConvertFrom-Json
$refresh = Get-Content -Raw -LiteralPath $refreshPath | ConvertFrom-Json
$optimization = Get-Content -Raw -LiteralPath $optimizationPath | ConvertFrom-Json
$rls = Get-Content -Raw -LiteralPath $rlsPath
$roles = Get-Content -Raw -LiteralPath $rolesPath | ConvertFrom-Json

Assert-True ($theme.name -eq "Warehouse Analytics 2.0") "Unexpected theme name."
Assert-True ($theme.dataColors.Count -ge 8) "Theme must define at least eight data colors."
Assert-True ($null -ne $theme.visualStyles.'*'.'*'.title) "Theme must define global visual titles."
Assert-True ($roles.defaultBehavior -eq "deny") "RLS must deny access when no mapping exists."
Assert-True ("WarehouseAccess" -in @($roles.roles.name)) "Restricted WarehouseAccess role is missing."
Assert-True ($rls.Contains("USERPRINCIPALNAME()")) "Dynamic RLS must use the signed-in Power BI identity."
Assert-True ($rls.Contains("security_user_warehouse[is_active] = TRUE()")) "Dynamic RLS must honor active mappings."

$visiblePages = @($report.pages | Where-Object { -not $_.hidden -and $_.pageType -eq "standard" })
$visiblePageNames = @($visiblePages.name)
$navigation = $report.globalSettings.navigationPane
$navigationDestinations = @($navigation.buttons.destination)
Assert-True ($report.globalSettings.defaultDateFilter.type -eq "relative") "Default date filter must be relative."
Assert-True ($report.globalSettings.defaultDateFilter.period -eq "month") "Default KPI window must use months."
Assert-True ($report.globalSettings.defaultDateFilter.count -eq 1) "Default KPI window must match the API's rolling month."
Assert-True ($report.canvas.width -eq ($report.canvas.contentWidth + $report.globalSettings.layoutStandards.navigationWidth)) "Canvas width must reserve space for the navigation pane."
Assert-True ($navigation.contentOffset[0] -eq $report.globalSettings.layoutStandards.navigationWidth) "Content offset must match navigation width."
Assert-True ($navigationDestinations.Count -eq $visiblePageNames.Count) "Navigation must contain one button per visible standard page."
foreach ($pageName in $visiblePageNames) {
    Assert-True ($pageName -in $navigationDestinations) "Navigation is missing page '$pageName'."
    Assert-True ($pageName -in @($navigation.applyToPages)) "Navigation is not applied to '$pageName'."
}

foreach ($page in $visiblePages) {
    Assert-True ($page.interactions.slicersFilterAll -eq $true) "Slicers must filter all visuals on '$($page.name)'."
    Assert-True ($page.interactions.visualSelectionCrossFilters -eq $true) "Cross-filtering must be enabled on '$($page.name)'."
    $slicerTitles = @($page.visuals | Where-Object { $_.type -eq "slicer" } | ForEach-Object { $_.title })
    Assert-True ("Date Range" -in $slicerTitles) "Date Range slicer is missing from '$($page.name)'."
    Assert-True ("Warehouse" -in $slicerTitles) "Warehouse slicer is missing from '$($page.name)'."
}

$pageNames = @($report.pages.name)
$drillTargets = @($report.pages.visuals | Where-Object { $_.drillthroughTarget } | ForEach-Object { $_.drillthroughTarget })
foreach ($target in $drillTargets) {
    Assert-True ($target -in $pageNames) "Drill-through target '$target' does not exist."
}

$bookmarkNames = @($report.bookmarks.name)
$visualIds = @($report.pages.visuals.id)
foreach ($button in @($report.pages.visuals | Where-Object { $_.action -eq "bookmark" })) {
    Assert-True ($button.bookmark -in $bookmarkNames) "Button '$($button.id)' references missing bookmark '$($button.bookmark)'."
}
foreach ($bookmark in $report.bookmarks) {
    foreach ($visualId in @($bookmark.display.show) + @($bookmark.display.hide)) {
        Assert-True ($visualId -in $visualIds) "Bookmark '$($bookmark.name)' references missing visual '$visualId'."
    }
}

$policyTables = @($refresh.incrementalRefreshPolicies.table)
Assert-True (($policyTables | Sort-Object -Unique).Count -eq $policyTables.Count) "Incremental refresh tables must be unique."
foreach ($factTable in @("fact_inventory", "fact_shipment", "fact_labor")) {
    Assert-True ($factTable -in $policyTables) "Incremental refresh policy is missing '$factTable'."
}
Assert-True ($refresh.serviceSchedule.times.Count -ge 1) "At least one scheduled refresh time is required."

$reportAndMeasureText = Get-Content -Raw -LiteralPath $reportPath
Get-ChildItem -LiteralPath (Join-Path $powerBiRoot "measures") -Filter "*.dax" | ForEach-Object {
    $reportAndMeasureText += Get-Content -Raw -LiteralPath $_.FullName
}
foreach ($tableProperty in $optimization.removeFromReportModel.PSObject.Properties) {
    foreach ($column in $tableProperty.Value) {
        $qualifiedColumn = "$($tableProperty.Name)[$column]"
        Assert-True (-not $reportAndMeasureText.Contains($qualifiedColumn)) "Removed column '$qualifiedColumn' is still referenced by the report or a measure."
    }
}

foreach ($aggregation in $optimization.aggregations) {
    Assert-True ($aggregation.storageMode -eq "Import") "Aggregation '$($aggregation.table)' must use Import mode."
    Assert-True ($aggregation.precedence -gt 0) "Aggregation '$($aggregation.table)' must have positive precedence."
    $sqlPath = Join-Path $repoRoot "dbt_warehouse\models\marts\aggregations\$($aggregation.table).sql"
    Assert-True (Test-Path -LiteralPath $sqlPath) "Aggregation model '$($aggregation.table)' is missing."
    $sql = Get-Content -Raw -LiteralPath $sqlPath
    foreach ($column in $aggregation.grain) {
        Assert-True ($sql -match [regex]::Escape($column)) "Aggregation '$($aggregation.table)' does not expose grain column '$column'."
    }
    foreach ($mapping in $aggregation.mappings.PSObject.Properties) {
        Assert-True ($sql -match [regex]::Escape($mapping.Name)) "Aggregation '$($aggregation.table)' does not expose mapped column '$($mapping.Name)'."
    }
}
$aggregationPrecedence = @($optimization.aggregations.precedence)
Assert-True (($aggregationPrecedence | Sort-Object -Unique).Count -eq $aggregationPrecedence.Count) "Aggregation precedence values must be unique."

$measureText = ""
Get-ChildItem -LiteralPath (Join-Path $powerBiRoot "measures") -Filter "*.dax" | ForEach-Object {
    $measureText += Get-Content -Raw -LiteralPath $_.FullName
}
$apiKpiText = Get-Content -Raw -LiteralPath $apiKpiPath
$coreKpiContracts = @(
    @{ Api = "Total Inventory Value"; Dax = "Total Inventory Value (Cost) | USD" },
    @{ Api = "Stock-Out Rate"; Dax = "Stock Out Rate | %" },
    @{ Api = "Items Below Reorder Point"; Dax = "Items Below Reorder Point | Items" },
    @{ Api = "Inventory Accuracy"; Dax = "Inventory Accuracy | %" },
    @{ Api = "Days of Supply"; Dax = "Days of Supply | Days" },
    @{ Api = "On-Time Delivery Rate"; Dax = "On-Time Delivery Rate | %" },
    @{ Api = "Cost Per Shipment"; Dax = "Cost Per Shipment | USD/Shipment" },
    @{ Api = "Cancellation Rate"; Dax = "Cancellation Rate | %" },
    @{ Api = "Average Transit Days"; Dax = "Average Transit Days | Days" },
    @{ Api = "Average Units Per Hour"; Dax = "Average Units Per Hour | Units/Hour" },
    @{ Api = "Error Rate"; Dax = "Error Rate | %" },
    @{ Api = "Cost Per Unit Processed"; Dax = "Cost Per Unit Processed | USD/Unit" },
    @{ Api = "Labor Efficiency Index"; Dax = "Labor Efficiency Index | %" }
)
foreach ($contract in $coreKpiContracts) {
    Assert-True ($apiKpiText.Contains("`"$($contract.Api)`"")) "API KPI '$($contract.Api)' is missing."
    Assert-True ($measureText.Contains("$($contract.Dax) =")) "DAX KPI '$($contract.Dax)' is missing."
}
Assert-True ($measureText.Contains("KEEPFILTERS(fact_inventory[date_key]")) "Inventory measures must use the latest visible snapshot."
Assert-True ($measureText.Contains('fact_shipment[status] = "Delivered"')) "Shipment DAX must restrict OTD and transit KPIs to delivered shipments."
Assert-True ($apiKpiText.Contains("status = 'Delivered' AND delivery_performance = 'On Time'")) "API OTD numerator must contain only delivered shipments."

Write-Output "PASS: theme JSON and formatting defaults"
Write-Output "PASS: dynamic warehouse RLS is deny-by-default"
Write-Output "PASS: navigation covers $($visiblePages.Count) visible pages"
Write-Output "PASS: slicer and cross-filter configuration"
Write-Output "PASS: default date filter matches the KPI API window"
Write-Output "PASS: $($drillTargets.Count) drill-through references"
Write-Output "PASS: $($report.bookmarks.Count) bookmarks and button targets"
Write-Output "PASS: $($policyTables.Count) incremental refresh policies"
Write-Output "PASS: removed-column reference safety"
Write-Output "PASS: $($optimization.aggregations.Count) aggregation models and mappings"
Write-Output "PASS: $($coreKpiContracts.Count) API-to-Power BI KPI contracts"

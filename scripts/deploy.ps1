[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [switch]$FullRefresh,
    [switch]$RollbackOnFailure,
    [switch]$SkipDocker,
    [switch]$PlanOnly,
    [string]$BackupDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\environments\$Environment.psd1"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Environment configuration not found: $configPath"
}
$config = Import-PowerShellDataFile -LiteralPath $configPath

function Resolve-DeploymentTool {
    param([string]$LocalPath, [string]$CommandName)

    if (Test-Path -LiteralPath $LocalPath) {
        return (Resolve-Path -LiteralPath $LocalPath).Path
    }
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Required command '$CommandName' was not found."
    }
    return $command.Source
}

function Invoke-DeploymentCommand {
    param(
        [string]$Label,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $repoRoot
    )

    Write-Host "  $Label" -ForegroundColor DarkCyan
    if ($PlanOnly) {
        return
    }
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Label failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

$sqlServer = if ($env:SQL_SERVER) { $env:SQL_SERVER } else { $config.SqlServerDefault }
if ([string]::IsNullOrWhiteSpace($sqlServer)) {
    throw "SQL_SERVER must be set for the '$Environment' environment."
}

$database = if ($env:SQL_DATABASE) { $env:SQL_DATABASE } else { $config.Database }
if ($database -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Database names may contain only letters, numbers, underscores, and hyphens."
}
$driver = if ($env:DBT_DRIVER) { $env:DBT_DRIVER } else { $config.OdbcDriver }
$sqlUser = if ($env:SQL_USER) { $env:SQL_USER } else { $env:DBT_USER }
$sqlPassword = if ($env:SQL_PASSWORD) { $env:SQL_PASSWORD } else { $env:DBT_PASSWORD }

$sqlcmd = if ($PlanOnly) { "sqlcmd" } else { Resolve-DeploymentTool "" "sqlcmd" }
$python = if ($PlanOnly) {
    "python"
} else {
    Resolve-DeploymentTool (Join-Path $repoRoot ".venv\Scripts\python.exe") "python"
}
$dbt = if ($PlanOnly) {
    "dbt"
} else {
    Resolve-DeploymentTool (Join-Path $repoRoot ".venv\Scripts\dbt.exe") "dbt"
}

$sqlAuthArguments = @("-S", $sqlServer, "-b", "-V", "16")
if ($config.WindowsLogin) {
    $sqlAuthArguments += "-E"
} else {
    if ([string]::IsNullOrWhiteSpace($sqlUser) -or [string]::IsNullOrWhiteSpace($sqlPassword)) {
        throw "SQL_USER/SQL_PASSWORD or DBT_USER/DBT_PASSWORD must be set for SQL authentication."
    }
    $env:SQLCMDPASSWORD = $sqlPassword
    $sqlAuthArguments += @("-U", $sqlUser)
}

$env:DBT_SERVER = $sqlServer
$env:DBT_DATABASE = $database
$env:DBT_DRIVER = $driver
$env:DBT_WINDOWS_LOGIN = if ($config.WindowsLogin) { "True" } else { "False" }
$env:DBT_ENCRYPT = if ($config.Encrypt) { "True" } else { "False" }
$env:DBT_TRUST_CERT = if ($config.TrustCertificate) { "True" } else { "False" }
if (-not $config.WindowsLogin) {
    $env:DBT_USER = $sqlUser
    $env:DBT_PASSWORD = $sqlPassword
}

if (-not $env:WAREHOUSE_DB_CONNECTION_STRING) {
    $connection = "DRIVER={$driver};SERVER=$sqlServer;DATABASE=$database;"
    if ($config.WindowsLogin) {
        $connection += "Trusted_Connection=yes;"
    } else {
        $connection += "UID=$sqlUser;PWD=$sqlPassword;"
    }
    $connection += "Encrypt=$($config.Encrypt);TrustServerCertificate=$($config.TrustCertificate);"
    $env:WAREHOUSE_DB_CONNECTION_STRING = $connection
}

$effectiveBackupDirectory = if ($BackupDirectory) { $BackupDirectory } else { $config.BackupDirectory }
$backupPath = $null
$backupCreated = $false
$deploymentStarted = Get-Date
$deploymentStatus = "Failed"

Write-Host "=== Warehouse Analytics Deployment ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Server: $sqlServer" -ForegroundColor Yellow
Write-Host "Database: $database" -ForegroundColor Yellow
Write-Host "Mode: $(if ($PlanOnly) { 'Plan only' } elseif ($FullRefresh) { 'Full refresh' } else { 'Incremental' })" -ForegroundColor Yellow

try {
    if ($RollbackOnFailure) {
        if ([string]::IsNullOrWhiteSpace($effectiveBackupDirectory)) {
            throw "A server-side BackupDirectory is required with -RollbackOnFailure."
        }
        $backupName = "${database}_${Environment}_$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
        $backupPath = ($effectiveBackupDirectory.TrimEnd('/', '\') + "/" + $backupName)
        $escapedBackupPath = $backupPath.Replace("'", "''")
        $escapedDatabase = $database.Replace("]", "]]" )
        $backupQuery = "IF DB_ID(N'$database') IS NULL THROW 50001, 'Database does not exist; rollback backup cannot be created.', 1; BACKUP DATABASE [$escapedDatabase] TO DISK = N'$escapedBackupPath' WITH COPY_ONLY, INIT, CHECKSUM;"
        Invoke-DeploymentCommand "Creating rollback backup" $sqlcmd ($sqlAuthArguments + @("-d", "master", "-Q", $backupQuery))
        $backupCreated = -not $PlanOnly
    }

    Write-Host "`n[1/5] Running database migrations..." -ForegroundColor Green
    $migrationFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "database\migrations") -Filter "V*.sql" |
        Sort-Object Name
    foreach ($file in $migrationFiles) {
        Invoke-DeploymentCommand "Applying $($file.Name)" $sqlcmd ($sqlAuthArguments + @("-d", "master", "-i", $file.FullName))
    }

    Write-Host "`n[2/5] Running dbt build..." -ForegroundColor Green
    $dbtDirectory = Join-Path $repoRoot "dbt_warehouse"
    Invoke-DeploymentCommand "Installing dbt packages" $dbt @("deps") $dbtDirectory
    $dbtBuildArguments = @("build", "--target", $config.DbtTarget, "--profiles-dir", ".")
    if ($FullRefresh) {
        $dbtBuildArguments += "--full-refresh"
    }
    Invoke-DeploymentCommand "Building dbt project" $dbt $dbtBuildArguments $dbtDirectory

    Write-Host "`n[3/5] Running data validation..." -ForegroundColor Green
    Invoke-DeploymentCommand "Validating warehouse data" $python @(
        "scripts/validate_data.py",
        "--report",
        "scripts/reports/data_validation_$Environment.json"
    )

    Write-Host "`n[4/5] Preparing backend API..." -ForegroundColor Green
    if ($config.BuildDocker -and -not $SkipDocker) {
        $docker = if ($PlanOnly) { "docker" } else { Resolve-DeploymentTool "" "docker" }
        Invoke-DeploymentCommand "Building $($config.DockerTag)" $docker @(
            "build",
            "--label", "warehouse.environment=$Environment",
            "--tag", $config.DockerTag,
            "backend"
        )
    } else {
        Write-Host "  Docker build skipped for $Environment."
    }

    Write-Host "`n[5/5] Generating dbt documentation..." -ForegroundColor Green
    if ($config.GenerateDocs) {
        Invoke-DeploymentCommand "Generating dbt docs" $dbt @(
            "docs", "generate", "--target", $config.DbtTarget, "--profiles-dir", "."
        ) $dbtDirectory
    }

    $deploymentStatus = if ($PlanOnly) { "Planned" } else { "Succeeded" }
    Write-Host "`n=== Deployment $deploymentStatus ===" -ForegroundColor Cyan
}
catch {
    Write-Host "`nDeployment failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($RollbackOnFailure -and $backupCreated -and $backupPath) {
        Write-Host "Restoring database backup..." -ForegroundColor Yellow
        $escapedBackupPath = $backupPath.Replace("'", "''")
        $escapedDatabase = $database.Replace("]", "]]" )
        $restoreQuery = "ALTER DATABASE [$escapedDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [$escapedDatabase] FROM DISK = N'$escapedBackupPath' WITH REPLACE; ALTER DATABASE [$escapedDatabase] SET MULTI_USER;"
        try {
            Invoke-DeploymentCommand "Restoring $database" $sqlcmd ($sqlAuthArguments + @("-d", "master", "-Q", $restoreQuery))
        }
        catch {
            Write-Host "Automatic rollback failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    throw
}
finally {
    if (-not $PlanOnly) {
        $reportDirectory = Join-Path $repoRoot "scripts\reports"
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
        $report = [ordered]@{
            environment = $Environment
            status = $deploymentStatus
            started_at = $deploymentStarted.ToUniversalTime().ToString("o")
            completed_at = (Get-Date).ToUniversalTime().ToString("o")
            full_refresh = [bool]$FullRefresh
            rollback_backup = $backupPath
        }
        $report | ConvertTo-Json | Set-Content -LiteralPath (
            Join-Path $reportDirectory "deployment_$Environment.json"
        ) -Encoding utf8
    }
}

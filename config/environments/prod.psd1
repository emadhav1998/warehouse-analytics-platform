@{
    Name = "prod"
    SqlServerDefault = ""
    Database = "WarehouseAnalyticsDB"
    DbtTarget = "prod"
    OdbcDriver = "ODBC Driver 18 for SQL Server"
    WindowsLogin = $false
    Encrypt = $true
    TrustCertificate = $false
    BuildDocker = $true
    DockerTag = "warehouse-analytics-api:latest"
    GenerateDocs = $true
    BackupDirectory = "/var/opt/mssql/backup"
}

@{
    Name = "dev"
    SqlServerDefault = "localhost"
    Database = "WarehouseAnalyticsDB"
    DbtTarget = "dev"
    OdbcDriver = "ODBC Driver 17 for SQL Server"
    WindowsLogin = $true
    Encrypt = $false
    TrustCertificate = $true
    BuildDocker = $false
    DockerTag = "warehouse-analytics-api:dev"
    GenerateDocs = $true
    BackupDirectory = "C:\SqlBackups"
}

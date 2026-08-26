@{
    Name = "staging"
    SqlServerDefault = ""
    Database = "WarehouseAnalyticsDB"
    DbtTarget = "staging"
    OdbcDriver = "ODBC Driver 18 for SQL Server"
    WindowsLogin = $false
    Encrypt = $true
    TrustCertificate = $false
    BuildDocker = $true
    DockerTag = "warehouse-analytics-api:staging"
    GenerateDocs = $true
    BackupDirectory = "/var/opt/mssql/backup"
}

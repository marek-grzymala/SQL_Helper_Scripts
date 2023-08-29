SELECT p.[name] AS [PackageName],
       [description] AS [PackageDescription],
       CASE [packagetype]
           WHEN 0 THEN
               'Undefined'
           WHEN 1 THEN
               'SQL Server Import and Export Wizard'
           WHEN 2 THEN
               'DTS Designer in SQL Server 2000'
           WHEN 3 THEN
               'SQL Server Replication'
           WHEN 5 THEN
               'SSIS Designer'
           WHEN 6 THEN
               'Maintenance Plan Designer or Wizard'
       END AS [PackageType],
       CASE [packageformat]
           WHEN 0 THEN
               'SSIS 2005 version'
           WHEN 1 THEN
               'SSIS 2008 version'
       END AS [PackageFormat],
       p.[createdate],
       CAST(CAST(packagedata AS VARBINARY(MAX)) AS XML) PackageXML
FROM [msdb].[dbo].[sysssispackages] p;
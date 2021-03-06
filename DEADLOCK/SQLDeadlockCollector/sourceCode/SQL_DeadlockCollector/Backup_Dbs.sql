-- 2008
BACKUP DATABASE [SQL_Analysis_Code]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Code_2008.bak'
 WITH FORMAT, INIT,  NAME = N'SQL_Analysis_Code v1.0', COMPRESSION
GO

BACKUP DATABASE [SQL_Analysis_Data]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Data_2008.bak' 
WITH FORMAT, INIT,  NAME = N'SQL_Analysis_Data v1.0', COMPRESSION
GO

BACKUP DATABASE [SQL_Analysis_Reporting]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Reporting_2008.bak' 
WITH FORMAT, INIT,  NAME = N'SQL_Analysis_Reporting v1.0', COMPRESSION
GO

-- 2012
BACKUP DATABASE [SQL_Analysis_Code]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Code_2012.bak'
 WITH FORMAT, INIT, COMPRESSION
 ,  NAME = N'SQL_Analysis_Code v1.0'

BACKUP DATABASE [SQL_Analysis_Data]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Data_2012.bak'
 WITH FORMAT, INIT, COMPRESSION
 ,  NAME = N'SQL_Analysis_Data v1.0'

BACKUP DATABASE [SQL_Analysis_Reporting]
TO  DISK = N'D:\SQLData\SQLBackup\SQL_Analysis_Reporting_2012.bak'
 WITH FORMAT, INIT, COMPRESSION
 ,  NAME = N'SQL_Analysis_Reporting v1.0'


BACKUP DATABASE [SIRIUS1_DEV_1]
TO  DISK = N'C:\MSSQL\Backup\SIRIUS1_DEV_1.bak'
WITH COPY_ONLY
   , NOFORMAT
   , INIT
   , NAME = N'SIRIUS1_DEV_1-Full Database Backup'
   , SKIP
   , NOREWIND
   , NOUNLOAD
   , COMPRESSION
   , STATS = 1
   , CHECKSUM
GO
DECLARE @backupSetId AS INT
SELECT @backupSetId = [position]
FROM [msdb]..[backupset]
WHERE [database_name] = N'SIRIUS1_DEV_1'
AND   [backup_set_id] = (SELECT MAX([backup_set_id])FROM [msdb]..[backupset] WHERE [database_name] = N'SIRIUS1_DEV_1')
IF @backupSetId IS NULL
BEGIN
    RAISERROR(N'Verify failed. Backup information for database ''SIRIUS1_DEV_1'' not found.', 16, 1)
END
RESTORE VERIFYONLY FROM DISK = N'C:\MSSQL\Backup\SIRIUS1_DEV_1.bak' WITH FILE = @backupSetId, NOUNLOAD, NOREWIND
GO

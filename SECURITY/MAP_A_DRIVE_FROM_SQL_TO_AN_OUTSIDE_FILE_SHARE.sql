-- To allow advanced options to be changed.
EXEC [sys].[sp_configure] 'show advanced options', 1;
GO
-- To update the currently configured value for advanced options.
RECONFIGURE;
GO
-- To enable the feature.
EXEC [sys].[sp_configure] 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO

-- ///////////////////////// MAP DRIVE: //////////////////////////////////////////////
EXEC [master]..[xp_cmdshell] 'net use Y: \\YourBackupServer\ShareWithBackups /PERSISTENT:Y /USER:YourADUserName@DomainName.Local YourPassw0rdHere'

RESTORE HEADERONLY FROM DISK = N'Y:\AdventureWorks2014.bak';

-- ////////////////////////// NOW DO THE BACKUP: ///////////////////////////////////////
BACKUP DATABASE [AdventureWorks2014]
TO  DISK = N'Y:\AdventureWorks2014.bak'
WITH COPY_ONLY
   , NOFORMAT
   , NOINIT
   , NAME = N'AdventureWorks2014-Full Database Backup'
   , SKIP
   , NOREWIND
   , NOUNLOAD
   , STATS = 1
   , CHECKSUM
GO
DECLARE @backupSetId AS INT
SELECT @backupSetId = [position]
FROM [msdb]..[backupset]
WHERE [database_name] = N'AdventureWorks2014'
AND   [backup_set_id] = (SELECT MAX([backup_set_id])FROM [msdb]..[backupset] WHERE [database_name] = N'AdventureWorks2014')
IF @backupSetId IS NULL
BEGIN
    RAISERROR(N'Verify failed. Backup information for database ''AdventureWorks2014'' not found.', 16, 1)
END
RESTORE VERIFYONLY FROM DISK = N'Y:\AdventureWorks2014.bak' WITH FILE = @backupSetId, NOUNLOAD, NOREWIND
GO
-- /////////////////////////  END OF BACKUP ///////////////////////////////////////////
-- /////////////////////////  DISCONNECT DRIVE: ///////////////////////////////////////
-- //IF YOU DO NOT DO IT YOU'RE GOING TO LOCK YOUR ACCOUNT AFTER ITS PASWORD CHANGES!!!//
EXEC [master]..[xp_cmdshell] 'net use'
EXEC [master]..[xp_cmdshell] 'net use B: /DELETE'

-- disable the feature.
EXEC [sys].[sp_configure] 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO

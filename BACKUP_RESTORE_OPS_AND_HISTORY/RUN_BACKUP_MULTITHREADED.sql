DECLARE @DayTime NVARCHAR(32)
SELECT @DayTime = REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE() ,20), ':', '-'), ' ','_')
--PRINT @DayTime

DECLARE @DBName NVARCHAR(256) 
DECLARE @BackupName NVARCHAR(256)
DECLARE @BackupRootPath NVARCHAR(256)
DECLARE @BackupFilePath1 NVARCHAR(256), @BackupFilePath2 NVARCHAR(256), @BackupFilePath3 NVARCHAR(256), @BackupFilePath4 NVARCHAR(256), @BackupFilePath5 NVARCHAR(256), @BackupFilePath6 NVARCHAR(256), @BackupFilePath7 NVARCHAR(256), @BackupFilePath8 NVARCHAR(256)


SET @DBName = N'YourDbNameHere'
SET @BackupName = @DBName+'-Full Database Backup'
SET @BackupRootPath = NULL -- set it to your own path if you want to place the backup in a folder other than default backup path, for example  N'D:\SQLBACKUP'

IF (@BackupRootPath IS NULL)
BEGIN
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory', @BackupRootPath OUTPUT 
END

SET @BackupFilePath1 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_1.bak'
SET @BackupFilePath2 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_2.bak'
SET @BackupFilePath3 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_3.bak'
SET @BackupFilePath4 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_4.bak'
SET @BackupFilePath5 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_5.bak'
SET @BackupFilePath6 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_6.bak'
SET @BackupFilePath7 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_7.bak'
SET @BackupFilePath8 = @BackupRootPath+'\'+@DBName+'_'+@DayTime+'_8.bak'

PRINT N'Backing up database ['+@DBName+'] to '+@BackupRootPath

BACKUP DATABASE @DBName TO
DISK = @BackupFilePath1,  
DISK = @BackupFilePath2,  
DISK = @BackupFilePath3,  
DISK = @BackupFilePath4,  
DISK = @BackupFilePath5,  
DISK = @BackupFilePath6,  
DISK = @BackupFilePath7,  
DISK = @BackupFilePath8
WITH  COPY_ONLY, NOFORMAT, NOINIT,  NAME = @BackupName, SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 1, CHECKSUM
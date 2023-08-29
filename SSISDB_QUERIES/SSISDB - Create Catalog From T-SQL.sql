USE [master];
GO

SET XACT_ABORT ON

/* ************************************************************************************************* */
/* 0. - Check if you are running on Windows: */
/* ************************************************************************************************* */
DECLARE @ErrorMsg NVARCHAR(1024);
IF NOT (CHARINDEX('Windows', @@VERSION) > 0)
BEGIN
    SELECT @ErrorMsg = N'SSIS Catalog is supported on Windows only!'
    +CHAR(13)+CHAR(10)+'For more info, see: https://docs.microsoft.com/en-us/sql/integration-services/catalog/ssis-catalog?view=sql-server-ver15';
    RAISERROR(@ErrorMsg, 20, -1) WITH LOG
END;

/* ************************************************************************************************* */
/* 1. - Check if you are sysadmin member: */
/* ************************************************************************************************* */
DECLARE @is_sysadmin BIT;
SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER('sysadmin'), 0);
IF (@is_sysadmin <> 1)
BEGIN
    RAISERROR(21089, 16, 1) WITH NOWAIT;
END;

/* ************************************************************************************************* */
/* 2. - Check if SQL you are running the right SQL Version: */
/* ************************************************************************************************* */
IF CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT) < 11
    RAISERROR(27193, 16, 1, 'Denali or later') WITH NOWAIT;

EXEC sys.sp_configure N'clr enabled', N'1';
RECONFIGURE;
GO

/* ************************************************************************************************* */
/* 3. - Verify that Common Language Runtime(CLR) is enabled on this instance: */
/* ************************************************************************************************* */
DECLARE @ErrorMsg NVARCHAR(1024);
IF (
   (
       SELECT TOP 1
              [value_in_use]
       FROM sys.configurations
       WHERE [name] = 'clr enabled'
   ) <> 1
   )
BEGIN
    SELECT @ErrorMsg = N'Common Language Runtime(CLR) is not enabled on this instance ';
    RAISERROR(@ErrorMsg, 16, 1) WITH NOWAIT;
END;

DECLARE @ssis_path_from_reg NVARCHAR(1024);
DECLARE @product_version VARCHAR(20);
SELECT @product_version = SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) + '0';

/* ************************************************************************************************* */
/* 4. - Save the SSIS Path read from registry: */
/* ************************************************************************************************* */
DECLARE @regkey NVARCHAR(1024);
SELECT @regkey = N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\' + @product_version + N'\\SSIS\\Setup\\DTSPath';
EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE',
                           @regkey,
                           N'',
                           @ssis_path_from_reg OUTPUT;

DECLARE @SSISDBBackupFilePath NVARCHAR(2048);
DECLARE @MDFpath NVARCHAR(1024);
DECLARE @LDFpath NVARCHAR(1024);
DECLARE @CatalogFileExists BIT;

IF OBJECT_ID(N'tempdb..#t') IS NOT NULL
BEGIN
    DROP TABLE #t;
    PRINT ('Dropped Temp Table #t');
END;
CREATE TABLE #t
(
    file_exists INT,
    is_directory INT,
    parent_directory_exists INT
);

BEGIN
    SELECT @SSISDBBackupFilePath = @ssis_path_from_reg + N'Binn\SSISDBBackup.bak';
    INSERT #t
    EXEC xp_fileexist @SSISDBBackupFilePath;
    SELECT TOP 1
           @CatalogFileExists = file_exists
    FROM #t;
    TRUNCATE TABLE #t;
END;

IF (@CatalogFileExists <> 1)
BEGIN
    SELECT @ErrorMsg = N'Could not find the SSISDBBackup.bak file in the path: ' + @ssis_path_from_reg + N'\\Binn\\';
    RAISERROR(@ErrorMsg, 16, 1) WITH NOWAIT;
END;

SET NOCOUNT ON;

/* ************************************************************************************************* */
/* 5. - Check if SSISDB already exists: */
/* ************************************************************************************************* */
IF DB_ID('SSISDB') IS NOT NULL
    RAISERROR(27135, 16, 1, 'SSISDB');


/* Save master.mdf file path (to use it later when creating SSISDB): */
DECLARE @master_file_path NVARCHAR(1024) = CONVERT(NVARCHAR(1024), SERVERPROPERTY('MasterFile'));
SELECT @master_file_path = SUBSTRING(@master_file_path, 1, CHARINDEX(N'master.mdf', LOWER(@master_file_path)) - 1);

/* ************************************************************************************************* */
/* 6. - Check if SSISDB.mdf file already exists: */
/* ************************************************************************************************* */
BEGIN
    SELECT @MDFpath = @master_file_path + N'SSISDB.mdf';
    INSERT #t
    EXEC xp_fileexist @MDFpath;
    SELECT TOP 1
           @CatalogFileExists = file_exists
    FROM #t;
    TRUNCATE TABLE #t;
END;

IF (@CatalogFileExists <> 0)
BEGIN
    SELECT @ErrorMsg = N'File: ' + @MDFpath + N' already exists';
    RAISERROR(@ErrorMsg, 16, 1) WITH NOWAIT;
END;

/* ************************************************************************************************* */
/* 7. - Check if SSISDB.ldf file already exists: */
/* ************************************************************************************************* */
BEGIN
    SELECT @LDFpath = @master_file_path + N'SSISDB.ldf';
    INSERT #t
    EXEC xp_fileexist @LDFpath;
    SELECT TOP 1
           @CatalogFileExists = file_exists
    FROM #t;
    TRUNCATE TABLE #t;
END;

IF (@CatalogFileExists <> 0)
BEGIN
    SELECT @ErrorMsg = N'File: ' + @LDFpath + N' already exists';
    RAISERROR(@ErrorMsg, 16, 1) WITH NOWAIT;
END;

/* ************************************************************************************************* */
/* 8. - Restore SSISDB: */
/* ************************************************************************************************* */
/*
EXEC sp_executesql N'RESTORE FILELISTONLY FROM DISK = @backupfile',
                   N'@backupfile nvarchar(67)',
                   @backupfile = @SSISDBBackupFilePath;
*/


EXEC sp_executesql N'RESTORE DATABASE @databaseName FROM DISK = @backupFile  WITH REPLACE, MOVE @dataName TO @dataFilePath, MOVE @logName TO @logFilePath',
                   N'@databaseName nvarchar(6),@dataName nvarchar(4),@dataFilePath nvarchar(75),@logName nvarchar(3),@logFilePath nvarchar(75),@backupFile nvarchar(67)',
                   @databaseName = N'SSISDB',
                   @dataName = N'data',
                   @dataFilePath = @MDFpath,
                   @logName = N'log',
                   @logFilePath = @LDFpath,
                   @backupfile = @SSISDBBackupFilePath;

IF ((SELECT @@ERROR) = 0)
BEGIN
    PRINT ('Database SSISDB Restored successfully');
END;
ELSE
BEGIN
    SELECT @ErrorMsg
        = N'Could not restore SSISDB from backup file: ' + @SSISDBBackupFilePath + N' into: ' + @MDFpath + N' and '
          + @LDFpath;
    RAISERROR(@ErrorMsg, 16, 1) WITH NOWAIT;
END;
GO

/* ************************************************************************************************* */
/* 9. - Set SSIDB to READ_WRITE: */
/* ************************************************************************************************* */
USE [master];
GO

IF EXISTS
(
    SELECT [name]
    FROM sys.databases
    WHERE [name] = 'SSISDB'
          AND [is_read_only] = 1
)
    ALTER DATABASE [SSISDB] SET READ_WRITE WITH ROLLBACK IMMEDIATE;
GO


/* ************************************************************************************************* */
/* 10. - Create Master Key in SSISDB encrypted by your password: */
/* ************************************************************************************************* */
USE [SSISDB];
GO

DECLARE @_SSISDB_Password NVARCHAR(256) = N'YourP@ssw0rdHere'; /* choose your password here that meets the operating system policy requirements and is complex enough */

IF EXISTS
(
    SELECT [name]
    FROM sys.symmetric_keys
    WHERE [name] = '##MS_DatabaseMasterKey##'
)
    DROP MASTER KEY;

EXEC sp_executesql N'USE [SSISDB];
                   DECLARE @pwd nvarchar(4000) = REPLACE(@password, N'''''''', N'''''''''''');
                   EXEC(''CREATE MASTER KEY ENCRYPTION BY PASSWORD = '''''' + @pwd + '''''''');',
N'@password nvarchar(13)',
@password = @_SSISDB_Password;


/* ************************************************************************************************* */
/* 11. - Add Microsoft.SqlServer.IntegrationServices.Server.dll assembly: */
/*     - without this step you won't be able to create any objects under SSIDB Catalog  */
/* ************************************************************************************************* */
USE [master];
GO
DECLARE @productVersion NVARCHAR(128);
DECLARE @majorVersion INT;
DECLARE @minorVersion INT;
DECLARE @buildVersion INT;
DECLARE @revisionVersion INT;
DECLARE @product_version VARCHAR(20);
DECLARE @ssis_path_from_reg NVARCHAR(1024);
DECLARE @ssis_assembly_path NVARCHAR(1024);
DECLARE @sql NVARCHAR(2048);

SET @productVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
SET @majorVersion = CONVERT(INT, PARSENAME(@productVersion, 4));
SET @minorVersion = CONVERT(INT, PARSENAME(@productVersion, 3));
SET @buildVersion = CONVERT(INT, PARSENAME(@productVersion, 2));
SET @revisionVersion = CONVERT(INT, PARSENAME(@productVersion, 1));
SET @product_version = SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) + '0';

DECLARE @regkey NVARCHAR(1024);
SELECT @regkey = N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\' + @product_version + N'\\SSIS\\Setup\\DTSPath';
EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE',
                           @regkey,
                           N'',
                           @ssis_path_from_reg OUTPUT;
SELECT @ssis_assembly_path = @ssis_path_from_reg + N'Binn\\Microsoft.SqlServer.IntegrationServices.Server.dll';

/* All versions before SQL 14 RC1 use asymmetric key and login */
/* 14.0.800.11 is an intermediate version between RC0 and RC1. This feature should be enabled in RC1 */
/* All versions from SQL 14 RC1 use trusted assembly */
IF NOT (
           @majorVersion > 14
           OR
           (
               @majorVersion = 14
               AND
               (
                   @minorVersion > 0
                   OR
                   (
                       @minorVersion = 0
                       AND
                       (
                           @buildVersion > 800
                           OR
                           (
                               @buildVersion = 800
                               AND @revisionVersion > 11
                           )
                       )
                   )
               )
           )
       )
BEGIN
    IF EXISTS
    (
        SELECT [name]
        FROM sys.server_principals
        WHERE name = '##MS_SQLEnableSystemAssemblyLoadingUser##'
    )
        DROP LOGIN ##MS_SQLEnableSystemAssemblyLoadingUser##;

    IF EXISTS
    (
        SELECT *
        FROM sys.asymmetric_keys
        WHERE name = 'MS_SQLEnableSystemAssemblyLoadingKey'
    )
        DROP ASYMMETRIC KEY MS_SQLEnableSystemAssemblyLoadingKey;

    SET @sql = N'CREATE ASYMMETRIC KEY MS_SQLEnableSystemAssemblyLoadingKey
    FROM EXECUTABLE FILE = ''' + @ssis_path_from_reg + N'Binn\\Microsoft.SqlServer.IntegrationServices.Server.dll'';';
    --PRINT @sql
    EXEC sp_executesql @sql;

    CREATE LOGIN ##MS_SQLEnableSystemAssemblyLoadingUser## FROM ASYMMETRIC KEY MS_SQLEnableSystemAssemblyLoadingKey;
    GRANT UNSAFE ASSEMBLY TO ##MS_SQLEnableSystemAssemblyLoadingUser##;

END;
ELSE
BEGIN
    DECLARE @asm_bin VARBINARY(MAX);
    DECLARE @isServerHashCode VARBINARY(64);

    SELECT @sql
        = N'
        SELECT @asm_bin = BulkColumn
        FROM
        OPENROWSET(BULK
                      ''' + @ssis_assembly_path
          + N''',
                      SINGLE_BLOB
                  )
        AS dll;
        ';
    EXEC sp_executesql @sql,
                       N'@asm_bin VARBINARY(MAX) OUTPUT',
                       @asm_bin OUTPUT;

    SELECT @isServerHashCode = HASHBYTES('SHA2_512', @asm_bin);
    IF NOT EXISTS
    (
        SELECT *
        FROM sys.trusted_assemblies
        WHERE hash = @isServerHashCode
    )
        EXEC sys.sp_add_trusted_assembly @isServerHashCode, @ssis_assembly_path;

END;

/* ************************************************************************************************* */
/* 12. - Create startup stored procedure: */
/* ************************************************************************************************* */

IF EXISTS (SELECT name FROM sys.procedures WHERE name = N'sp_ssis_startup')
BEGIN
    EXEC sp_procoption N'sp_ssis_startup', 'startup', 'off';
    DROP PROCEDURE [sp_ssis_startup];
END;
GO

CREATE PROCEDURE [dbo].[sp_ssis_startup]
AS
SET NOCOUNT ON;
/* Currently, the IS Store name is 'SSISDB' */
IF DB_ID('SSISDB') IS NULL
    RETURN;

IF NOT EXISTS
(
    SELECT name
    FROM [SSISDB].sys.procedures
    WHERE name = N'startup'
)
    RETURN;

/*Invoke the procedure in SSISDB  */
/* Use dynamic sql to handle AlwaysOn non-readable mode*/
DECLARE @script NVARCHAR(500);
SET @script = N'EXEC [SSISDB].[catalog].[startup]';
EXECUTE sp_executesql @script;
GO

/* set the sp_ssis_startup procedure for autoexecution: */
IF (1 = 1)
BEGIN
    EXEC sp_procoption N'sp_ssis_startup', 'startup', 'on';
END;

/* ************************************************************************************************* */
/* 13. - Create and map ##MS_SSISServerCleanupJobUser## */
/* ************************************************************************************************* */

USE [master]
GO

IF EXISTS
(
    SELECT *
    FROM sys.server_principals
    WHERE name = '##MS_SSISServerCleanupJobLogin##'
)
    DROP LOGIN ##MS_SSISServerCleanupJobLogin##;

DECLARE @loginPassword NVARCHAR(256);
SELECT @loginPassword = REPLACE(CONVERT(NVARCHAR(256), CRYPT_GEN_RANDOM(64)), N'''', N'''''');
EXEC ('CREATE LOGIN ##MS_SSISServerCleanupJobLogin## WITH PASSWORD =''' + @loginPassword + ''', CHECK_POLICY = OFF');

ALTER LOGIN ##MS_SSISServerCleanupJobLogin## DISABLE;

USE [SSISDB];
GO

IF EXISTS
(
    SELECT name
    FROM sys.database_principals
    WHERE name = '##MS_SSISServerCleanupJobUser##'
)
    DROP USER ##MS_SSISServerCleanupJobUser##;


CREATE USER ##MS_SSISServerCleanupJobUser## FOR LOGIN ##MS_SSISServerCleanupJobLogin##;
GRANT EXECUTE
ON [internal].[cleanup_server_retention_window]
TO  ##MS_SSISServerCleanupJobUser##;

GRANT EXECUTE
ON [internal].[cleanup_server_project_version]
TO  ##MS_SSISServerCleanupJobUser##;

USE [master];
GO

GRANT VIEW SERVER STATE TO ##MS_SSISServerCleanupJobLogin##;

USE [msdb];
GO

IF NOT EXISTS
(
    SELECT *
    FROM [sys].[server_principals]
    WHERE [name] = '##MS_SSISServerCleanupJobLogin##'
)
    RAISERROR(27229, 16, 1, '##MS_SSISServerCleanupJobLogin##') WITH NOWAIT;

/* ************************************************************************************************* */
/* 13. - Create Maintenance Jobs and Map ##MS_SSISServerCleanupJobLogin## login */
/* ************************************************************************************************* */

USE [msdb];
GO

IF EXISTS
(
    SELECT name
    FROM sysjobs
    WHERE name = N'SSIS Server Maintenance Job'
)
    EXEC sp_delete_job @job_name = N'SSIS Server Maintenance Job';



IF EXISTS
(
    SELECT [name]
    FROM [sysjobs]
    WHERE [name] = N'SSIS Failover Monitor Job'
)
    EXEC sp_delete_job @job_name = N'SSIS Failover Monitor Job';


EXEC dbo.sp_add_job @job_name = N'SSIS Server Maintenance Job',
                    @enabled = 1,
                    @owner_login_name = '##MS_SSISServerCleanupJobLogin##',
                    @description = N'Runs every day. The job removes operation records from the database that are outside the retention window and maintains a maximum number of versions per project.';


DECLARE @IS_server_name NVARCHAR(30);
SELECT @IS_server_name = CONVERT(NVARCHAR, SERVERPROPERTY('ServerName'));

EXEC sp_add_jobserver @job_name = N'SSIS Server Maintenance Job',
                      @server_name = @IS_server_name;

EXEC sp_add_jobstep @job_name = N'SSIS Server Maintenance Job',
                    @step_name = N'SSIS Server Operation Records Maintenance',
                    @subsystem = N'TSQL',
                    @command = N'
	                           DECLARE @role int
	                           SET @role = (SELECT [role] FROM [sys].[dm_hadr_availability_replica_states] hars INNER JOIN [sys].[availability_databases_cluster] adc ON hars.[group_id] = adc.[group_id] WHERE hars.[is_local] = 1 AND adc.[database_name] =''SSISDB'')
	                           IF DB_ID(''SSISDB'') IS NOT NULL AND (@role IS NULL OR @role = 1)
		                       EXEC [SSISDB].[internal].[cleanup_server_retention_window]',
                    @database_name = N'msdb',
                    @on_success_action = 3,
                    @retry_attempts = 3,
                    @retry_interval = 3;


EXEC sp_add_jobstep @job_name = N'SSIS Server Maintenance Job',
                    @step_name = N'SSIS Server Max Version Per Project Maintenance',
                    @subsystem = N'TSQL',
                    @command = N'
	                           DECLARE @role int
	                           SET @role = (SELECT [role] FROM [sys].[dm_hadr_availability_replica_states] hars INNER JOIN [sys].[availability_databases_cluster] adc ON hars.[group_id] = adc.[group_id] WHERE hars.[is_local] = 1 AND adc.[database_name] =''SSISDB'')
	                           IF DB_ID(''SSISDB'') IS NOT NULL AND (@role IS NULL OR @role = 1)
		                       EXEC [SSISDB].[internal].[cleanup_server_project_version]',
                    @database_name = N'msdb',
                    @retry_attempts = 3,
                    @retry_interval = 3;


EXEC sp_add_jobschedule @job_name = N'SSIS Server Maintenance Job',
                        @name = 'SSISDB Scheduler',
                        @enabled = 1,
                        @freq_type = 4,     /*daily*/
                        @freq_interval = 1, /*every day*/
                        @freq_subday_type = 0x1,
                        @active_start_date = 20001231,
                        @active_end_date = 99991231,
                        @active_start_time = 0,
                        @active_end_time = 120000;
GO
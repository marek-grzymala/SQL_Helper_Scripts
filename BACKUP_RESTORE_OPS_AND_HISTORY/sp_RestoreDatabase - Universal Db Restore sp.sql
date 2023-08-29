
/*
adjusted to SQL2019 from: https://weblogs.sqlteam.com/dang/2009/06/13/restore-database-stored-procedure/
Example Use:

      EXEC #sp_RestoreDatabase_SQL2019

            @BackupFile = N'C:\mssql\Backup\TestDB_1.bak',
            @AdditionalOptions=N'STATS=1, REPLACE',
            @ExecuteRestoreImmediately = 'Y'

*/
IF OBJECT_ID(N'tempdb..#sp_RestoreDatabase_SQL2019') IS NOT NULL
    DROP PROCEDURE #sp_RestoreDatabase_SQL2019;

GO



CREATE PROCEDURE #sp_RestoreDatabase_SQL2019
    @BackupFile NVARCHAR(260),
    @NewDatabaseName sysname = NULL,
    @FileNumber INT = 1,
    @DataFolder NVARCHAR(260) = NULL,
    @LogFolder NVARCHAR(260) = NULL,
    @ExecuteRestoreImmediately CHAR(1) = 'N',
    @ChangePhysicalFileNames CHAR(1) = 'Y',
    @ChangeLogicalNames CHAR(1) = 'Y',
    @DatabaseOwner sysname = NULL,
    @AdditionalOptions NVARCHAR(500) = NULL
AS


/*

This procedure will generate and optionally execute a RESTORE DATABASE

script from the specified disk database backup file.

Parameters:

 

      @BackupFile: Required. Specifies fully-qualified path to the disk

            backup file. For remote (network) files, UNC path should

            be specified.  The SQL Server service account will need

            permissions to the file.

 

      @NewDatabaseName: Optional. Specifies the target database name

            for the restore.  If not specified, the database is

            restored using the original database name.

 

      @FileNumber: Optional. Specifies the file number of the desired

            backup set. This is needed only when when the backup file

            contains multiple backup sets. If not specified, a

            default of 1 is used.

 

      @DataFolder: Optional. Specifies the folder for all database data

            files. If not specified, data files are restored using the

            original file names and locations.

 

      @LogFolder: Optional. Specifies the folder for all database log

            files. If not specified, log files are restored to the

            original log file locations.

 

      @ExecuteRestoreImmediately: Optional. Specifies whether or not to

            execute the restore. When, 'Y' is specified, then restore is

            executed immediately.  When 'Y' is specified, the restore script

            is printed but not executed. If not specified, a default of 'N'

            is used.

           

      @ChangePhysicalFileNames: Optional. Indicates that physical file

            names are to be renamed during the restore to match the

            new database name. When 'Y' is specified, the leftmost

            part of the original file name matching the original

            database name is replaced with the new database name. The

            file name is not changed when 'N' is specified or if the

            leftmost part of the file name doesn't match the original

            database name. If not specified, a default of 'Y' is used.

 

      @ChangeLogicalNames: Optional. Indicates that logical file names

            are to be renamed following the restore to match the new

            database name. When 'Y' is specified, the leftmost part

            of the original file name matching the original database

            name is replaced with the new database name. The file name

            is not changed when 'N' is specified or if the leftmost

            part of the file name doesn't match the original database

            name. If not specified, a default of 'Y' is used.

           

      @DatabaseOwner: Optional. Specifies the new database owner

            (authorization) of the restored database.  If not specified, the

            database will be owned by the accunt used to restore the database.

           

      @AdditionalOptions:  Optional.  Specifies options to be added the the

            RESTORE statement WITH clause (e.g. STATS=5, REPLACE).  If not

            specified, only the FILE and MOVE are included.

 

Sample usages:

 

      --restore database with same name and file locations

      EXEC #sp_RestoreDatabase_SQL2019

            @BackupFile = N'C:\Backups\Foo.bak',

            @AdditionalOptions=N'STATS=5, REPLACE';

           

      Results:

      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000

      RESTORE DATABASE [MyDatabase]

            FROM DISK=N'C:\Backups\Foo.bak'

            WITH

                  FILE=1, STATS=5, REPLACE

 

      --restore database with new name and change logical and physical names

      EXEC #sp_RestoreDatabase_SQL2019

            @BackupFile = N'C:\Backups\Foo.bak',

            @NewDatabaseName = 'Foo2';

           

      Results:

      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000

      RESTORE DATABASE [Foo2]

            FROM DISK=N'C:\Backups\Foo.bak'

            WITH

                  FILE=1,

                        MOVE 'Foo' TO 'C:\DataFolder\Foo2.mdf',

                        MOVE 'Foo_log' TO 'D:\LogFolder\Foo2_log.LDF'

      ALTER DATABASE [Foo2]

                        MODIFY FILE (NAME='Foo', NEWNAME='Foo2');

      ALTER DATABASE [Foo2]

                        MODIFY FILE (NAME='Foo_log', NEWNAME='Foo2_log');

                       

      --restore database to different file folders and change owner after restore:

      EXEC #sp_RestoreDatabase_SQL2019

            @BackupFile = N'C:\Backups\Foo.bak',

            @DataFolder = N'E:\DataFiles',

            @LogFolder = N'F:\LogFiles',

            @DatabaseOwner = 'sa',

            @AdditionalOptions=N'STATS=5;

           

      Results:

      --Backup source: ServerName=MYSERVER, DatabaseName=Foo, BackupFinishDate=2009-06-13 11:20:52.000

      RESTORE DATABASE [Foo]

            FROM DISK=N'C:\Backups\Foo.bak'

            WITH

                  FILE=1,

                        MOVE 'Foo' TO 'E:\DataFiles\Foo.mdf',

                        MOVE 'Foo_log' TO 'F:\LogFiles\Foo_log.LDF'

      ALTER AUTHORIZATION ON DATABASE::[Foo] TO [sa]

*/



SET NOCOUNT ON;



DECLARE @LogicalName NVARCHAR(128),
        @PhysicalName NVARCHAR(260),
        @PhysicalFolderName NVARCHAR(260),
        @PhysicalFileName NVARCHAR(260),
        @NewPhysicalName NVARCHAR(260),
        @NewLogicalName NVARCHAR(128),
        @OldDatabaseName NVARCHAR(128),
        @RestoreStatement NVARCHAR(MAX),
        @Command NVARCHAR(MAX),
        @ReturnCode INT,
        @FileType CHAR(1),
        @ServerName NVARCHAR(128),
        @BackupFinishDate DATETIME,
        @Message NVARCHAR(4000),
        @ChangeLogicalNamesSql NVARCHAR(MAX),
        @AlterAuthorizationSql NVARCHAR(MAX),
        @Error INT;



DECLARE @BackupHeader TABLE
(
    [BackupName] NVARCHAR(128),
    [BackupDescription] NVARCHAR(255),
    [BackupType] TINYINT,
    [ExpirationDate] DATETIME,
    [Compressed] TINYINT,
    [Position] SMALLINT,
    [DeviceType] TINYINT,
    [UserName] NVARCHAR(128),
    [ServerName] NVARCHAR(128),
    [DatabaseName] NVARCHAR(128),
    [DatabaseVersion] INT,
    [DatabaseCreationDate] DATETIME,
    [BackupSize] BIGINT,
    [FirstLSN] DECIMAL(25, 0),
    [LastLSN] DECIMAL(25, 0),
    [CheckpointLSN] DECIMAL(25, 0),
    [DatabaseBackupLSN] DECIMAL(25, 0),
    [BackupStartDate] DATETIME,
    [BackupFinishDate] DATETIME,
    [SortOrder] SMALLINT,
    [CodePage] SMALLINT,
    [UnicodeLocaleId] INT,
    [UnicodeComparisonStyle] INT,
    [CompatibilityLevel] TINYINT,
    [SoftwareVendorId] INT,
    [SoftwareVersionMajor] INT,
    [SoftwareVersionMinor] INT,
    [SoftwareVersionBuild] INT,
    [MachineName] NVARCHAR(128),
    [Flags] INT,
    [BindingID] UNIQUEIDENTIFIER,
    [RecoveryForkID] UNIQUEIDENTIFIER,
    [Collation] NVARCHAR(128),
    [FamilyGUID] UNIQUEIDENTIFIER,
    [HasBulkLoggedData] BIT,
    [IsSnapshot] BIT,
    [IsReadOnly] BIT,
    [IsSingleUser] BIT,
    [HasBackupChecksums] BIT,
    [IsDamaged] BIT,
    [BeginsLogChain] BIT,
    [HasIncompleteMetaData] BIT,
    [IsForceOffline] BIT,
    [IsCopyOnly] BIT,
    [FirstRecoveryForkID] UNIQUEIDENTIFIER,
    [ForkPointLSN] DECIMAL(25, 0),
    [RecoveryModel] NVARCHAR(60),
    [DifferentialBaseLSN] DECIMAL(25, 0),
    [DifferentialBaseGUID] UNIQUEIDENTIFIER,
    [BackupTypeDescription] NVARCHAR(128),
    [BackupSetGUID] UNIQUEIDENTIFIER,
    [CompressedBackupSize] BIGINT,
    [Containment] TINYINT,
    [KeyAlgorithm] NVARCHAR(32),
    [EncryptorThumbprint] VARBINARY(20),
    [EncryptorType] NVARCHAR(32)
);



DECLARE @FileList TABLE
(
    [LogicalName] NVARCHAR(128),
    [PhysicalName] NVARCHAR(260),
    [Type] NCHAR(1),
    [FileGroupName] NVARCHAR(128),
    [Size] BIGINT,
    [MaxSize] BIGINT,
    [FileId] BIGINT,
    [CreateLSN] DECIMAL(25, 0),
    [DropLSN] DECIMAL(25, 0),
    [UniqueId] UNIQUEIDENTIFIER,
    [ReadOnlyLSN] DECIMAL(25, 0),
    [ReadWriteLSN] DECIMAL(25, 0),
    [BackupSizeInBytes] BIGINT,
    [SourceBlockSize] INT,
    [FileGroupId] INT,
    [LogGroupGUID] UNIQUEIDENTIFIER,
    [DifferentialBaseLSN] DECIMAL(25, 0),
    [DifferentialBaseGUID] UNIQUEIDENTIFIER,
    [IsReadOnly] BIT,
    [IsPresent] BIT,
    [TDEThumbprint] VARBINARY(20),
    [SnapshotUrl] NVARCHAR(336)
);



SET @Error = 0;

--add trailing backslash to folder names if not already specified

IF LEFT(REVERSE(@DataFolder), 1) <> '\'
    SET @DataFolder = @DataFolder + '\';

IF LEFT(REVERSE(@LogFolder), 1) <> '\'
    SET @LogFolder = @LogFolder + '\';

-- get backup header info and display

SET @RestoreStatement = N'RESTORE HEADERONLY

      FROM DISK=N''' + @BackupFile + N''' WITH FILE=' + CAST(@FileNumber AS NVARCHAR(10));

INSERT INTO @BackupHeader
EXEC ('RESTORE HEADERONLY FROM DISK=N''' + @BackupFile + ''' WITH FILE = 1');

SET @Error = @@ERROR;

IF @Error <> 0
    GOTO Done;

IF NOT EXISTS (SELECT * FROM @BackupHeader)
    GOTO Done;

SELECT @OldDatabaseName = DatabaseName,
       @ServerName = ServerName,
       @BackupFinishDate = BackupFinishDate
FROM @BackupHeader;

IF @NewDatabaseName IS NULL
    SET @NewDatabaseName = @OldDatabaseName;

SET @Message
    = N'--Backup source: ServerName=%s, DatabaseName=%s, BackupFinishDate='
      + CONVERT(NVARCHAR(23), @BackupFinishDate, 121);

RAISERROR(@Message, 0, 1, @ServerName, @OldDatabaseName) WITH NOWAIT;



-- get filelist info

SET @RestoreStatement = N'RESTORE FILELISTONLY

      FROM DISK=N''' + @BackupFile + N''' WITH FILE=' + CAST(@FileNumber AS NVARCHAR(10));

INSERT INTO @FileList
EXEC (@RestoreStatement);

SET @Error = @@ERROR;

IF @Error <> 0
    GOTO Done;

IF NOT EXISTS (SELECT * FROM @FileList)
    GOTO Done;



-- generate RESTORE DATABASE statement and ALTER DATABASE statements

SET @ChangeLogicalNamesSql = N'';

SET @RestoreStatement = N'RESTORE DATABASE ' + QUOTENAME(@NewDatabaseName) + N'

      FROM DISK=N'''    + @BackupFile + N'''' + N'

      WITH

            FILE='      + CAST(@FileNumber AS NVARCHAR(10));

DECLARE FileList CURSOR LOCAL STATIC READ_ONLY FOR
SELECT Type AS FileTyoe,
       LogicalName,

       --extract folder name from full path

       LEFT(PhysicalName, LEN(LTRIM(RTRIM(PhysicalName))) - CHARINDEX('\', REVERSE(LTRIM(RTRIM(PhysicalName)))) + 1) AS PhysicalFolderName,

       --extract file name from full path

       LTRIM(RTRIM(RIGHT(PhysicalName, CHARINDEX('\', REVERSE(PhysicalName)) - 1))) AS PhysicalFileName
FROM @FileList;



OPEN FileList;



WHILE 1 = 1
BEGIN

    FETCH NEXT FROM FileList
    INTO @FileType,
         @LogicalName,
         @PhysicalFolderName,
         @PhysicalFileName;

    IF @@FETCH_STATUS = -1
        BREAK;



    -- build new physical name

    SET @NewPhysicalName
        = CASE @FileType
              WHEN 'D' THEN
                  COALESCE(@DataFolder, @PhysicalFolderName)
                  + CASE
                        WHEN UPPER(@ChangePhysicalFileNames) IN ( 'Y', '1' )
                             AND LEFT(@PhysicalFileName, LEN(@OldDatabaseName)) = @OldDatabaseName THEN
                            @NewDatabaseName + RIGHT(@PhysicalFileName, LEN(@PhysicalFileName) - LEN(@OldDatabaseName))
                        ELSE
                            @PhysicalFileName
                    END
              WHEN 'L' THEN
                  COALESCE(@LogFolder, @PhysicalFolderName)
                  + CASE
                        WHEN UPPER(@ChangePhysicalFileNames) IN ( 'Y', '1' )
                             AND LEFT(@PhysicalFileName, LEN(@OldDatabaseName)) = @OldDatabaseName THEN
                            @NewDatabaseName + RIGHT(@PhysicalFileName, LEN(@PhysicalFileName) - LEN(@OldDatabaseName))
                        ELSE
                            @PhysicalFileName
                    END
          END;



    -- build new logical name

    SET @NewLogicalName = CASE
                              WHEN UPPER(@ChangeLogicalNames) IN ( 'Y', '1' )
                                   AND LEFT(@LogicalName, LEN(@OldDatabaseName)) = @OldDatabaseName THEN
                                  @NewDatabaseName + RIGHT(@LogicalName, LEN(@LogicalName) - LEN(@OldDatabaseName))
                              ELSE
                                  @LogicalName
                          END;



    -- generate ALTER DATABASE...MODIFY FILE statement if logical file name is different

    IF @NewLogicalName <> @LogicalName
        SET @ChangeLogicalNamesSql
            = @ChangeLogicalNamesSql + N'ALTER DATABASE ' + QUOTENAME(@NewDatabaseName)
              + N'

                  MODIFY FILE (NAME=''' + @LogicalName + N''', NEWNAME=''' + @NewLogicalName + N''');

'       ;



    -- add MOVE option as needed if folder and/or file names are changed

    IF @PhysicalFolderName + @PhysicalFileName <> @NewPhysicalName
    BEGIN

        SET @RestoreStatement = @RestoreStatement + N',

                  MOVE '''      + @LogicalName + N''' TO ''' + @NewPhysicalName + N'''';

    END;



END;

CLOSE FileList;

DEALLOCATE FileList;



IF @AdditionalOptions IS NOT NULL
    SET @RestoreStatement = @RestoreStatement + N', ' + @AdditionalOptions;



IF @DatabaseOwner IS NOT NULL
    SET @AlterAuthorizationSql
        = N'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@NewDatabaseName) + N' TO ' + QUOTENAME(@DatabaseOwner);

ELSE
    SET @AlterAuthorizationSql = N'';

--execute RESTORE statement

IF UPPER(@ExecuteRestoreImmediately) IN ( 'Y', '1' )
BEGIN



    RAISERROR(N'Executing:

%s', 0, 1, @RestoreStatement) WITH NOWAIT;

    EXEC (@RestoreStatement);

    SET @Error = @@ERROR;

    IF @Error <> 0
        GOTO Done;



    --execute ALTER DATABASE statement(s)

    IF @ChangeLogicalNamesSql <> ''
    BEGIN

        RAISERROR(N'Executing:

%s', 0, 1, @ChangeLogicalNamesSql) WITH NOWAIT;

        EXEC (@ChangeLogicalNamesSql);

        SET @Error = @@ERROR;

        IF @Error <> 0
            GOTO Done;

    END;



    IF @AlterAuthorizationSql <> ''
    BEGIN

        RAISERROR(N'Executing:

%s', 0, 1, @AlterAuthorizationSql) WITH NOWAIT;

        EXEC (@AlterAuthorizationSql);

        SET @Error = @@ERROR;

        IF @Error <> 0
            GOTO Done;

    END;



END;

ELSE
BEGIN

    RAISERROR(N'%s', 0, 1, @RestoreStatement) WITH NOWAIT;

    IF @ChangeLogicalNamesSql <> ''
    BEGIN

        RAISERROR(N'%s', 0, 1, @ChangeLogicalNamesSql) WITH NOWAIT;

    END;

    IF @AlterAuthorizationSql <> ''
    BEGIN

        RAISERROR(N'%s', 0, 1, @AlterAuthorizationSql) WITH NOWAIT;

    END;

END;



Done:



RETURN @Error;

GO


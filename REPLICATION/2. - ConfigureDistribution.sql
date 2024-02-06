USE [master]
GO

CREATE LOGIN [distributor_admin] WITH PASSWORD=N'Wk/qk9GNsaQxATqhm0oqHw58WvgFhi+1SoG72U8cNaw=', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON
GO

ALTER LOGIN [distributor_admin] ENABLE
GO

ALTER SERVER ROLE [sysadmin] ADD MEMBER [distributor_admin]
GO

EXEC [sys].[sp_adddistributor] @distributor = N'SRVRCORE2019\SQL2019', @password = N'Password1234$';
GO
EXEC [sys].[sp_adddistributiondb] @database = N'distribution'
                                , @data_folder = N'C:\MSSQL\Data'
                                , @log_folder = N'C:\MSSQL\Log'
                                , @log_file_size = 2
                                , @min_distretention = 0
                                , @max_distretention = 72
                                , @history_retention = 48
                                , @deletebatchsize_xact = 5000
                                , @deletebatchsize_cmd = 2000
                                , @security_mode = 1;
GO

USE [distribution]
GO

IF (NOT EXISTS (SELECT * FROM [sys].[sysobjects] WHERE [name] = 'UIProperties' AND [type] = 'U '))
    CREATE TABLE [UIProperties] ([id] INT);
IF (EXISTS (
               SELECT * FROM [fn_listextendedproperty]('SnapshotFolder', 'user', 'dbo', 'table', 'UIProperties', NULL, NULL)
           )
   )
EXEC [sys].[sp_updateextendedproperty] N'SnapshotFolder'
                                         , N'C:\MSSQL\Backup\ReplData'
                                         , 'user'
                                         , [dbo]
                                         , 'table'
                                         , 'UIProperties';
ELSE
    EXEC [sys].[sp_addextendedproperty] N'SnapshotFolder'
                                      , N'C:\MSSQL\Backup\ReplData'
                                      , 'user'
                                      , [dbo]
                                      , 'table'
                                      , 'UIProperties';
GO

EXEC [sys].[sp_adddistpublisher] @publisher = N'SRVRCORE2019\SQL2019'
                               , @distribution_db = N'distribution'
                               , @security_mode = 1
                               , @working_directory = N'C:\MSSQL\Backup\ReplData'
                               , @trusted = N'false'
                               , @thirdparty_flag = 0
                               , @publisher_type = N'MSSQLSERVER';
GO

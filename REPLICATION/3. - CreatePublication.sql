USE [test_db]
GO

EXEC [sys].[sp_replicationdboption] @dbname = N'test_db', @optname = N'publish', @value = N'true';
GO

--EXEC [sys].[sp_replicationdboption] @dbname = N'test_db', @optname = N'publish', @value = N'false';
--GO

-- Adding the transactional publication:
USE [test_db];
EXEC [sys].[sp_addpublication] @publication					 = N'test_db_pub_a'
                             , @description					 = N'Transactional publication of database ''test_db'' from Publisher ''USVMDEVWKSC026\SIRIUS''.'
                             , @sync_method					 = N'concurrent'
                             , @retention					 = 0
                             , @allow_push					 = N'true'
                             , @allow_pull					 = N'true'
                             , @allow_anonymous				 = N'true'
                             , @enabled_for_internet		 = N'false'
                             , @snapshot_in_defaultfolder	 = N'true'
                             , @compress_snapshot			 = N'false'
                             , @ftp_port					 = 21
                             , @ftp_login					 = N'anonymous'
                             , @allow_subscription_copy		 = N'false'
                             , @add_to_active_directory		 = N'false'
                             , @repl_freq					 = N'continuous'
                             , @status						 = N'active'
                             , @independent_agent			 = N'true'
                             , @immediate_sync				 = N'true'
                             , @allow_sync_tran				 = N'false'
                             , @autogen_sync_procs			 = N'false'
                             , @allow_queued_tran			 = N'false'
                             , @allow_dts					 = N'false'
                             , @replicate_ddl				 = 1
                             , @allow_initialize_from_backup = N'false'
                             , @enabled_for_p2p				 = N'false'
                             , @enabled_for_het_sub			 = N'false';
GO


EXEC [sys].[sp_addpublication_snapshot] @publication				 = N'test_db_pub_a'
                                      , @frequency_type				 = 1
                                      , @frequency_interval			 = 0
                                      , @frequency_relative_interval = 0
                                      , @frequency_recurrence_factor = 0
                                      , @frequency_subday			 = 0
                                      , @frequency_subday_interval	 = 0
                                      , @active_start_time_of_day	 = 0
                                      , @active_end_time_of_day		 = 235959
                                      , @active_start_date			 = 0
                                      , @active_end_date			 = 0
                                      , @job_login					 = NULL
                                      , @job_password				 = NULL
                                      , @publisher_security_mode	 = 1;


USE [test_db];
EXEC [sys].[sp_addarticle] @publication						= N'test_db_pub_a'
                         , @article							= N'test_table_01'
                         , @source_owner					= N'dbo'
                         , @source_object					= N'test_table_01'
                         , @type							= N'logbased'
                         , @description						= NULL
                         , @creation_script					= NULL
                         , @pre_creation_cmd				= N'drop'
                         , @schema_option					= 0x000000000803509F
                         , @identityrangemanagementoption	= N'manual'
                         , @destination_table				= N'test_table_01'
                         , @destination_owner				= N'dbo'
                         , @vertical_partition				= N'false'
                         , @ins_cmd							= N'CALL sp_MSins_dbotest_table_01'
                         , @del_cmd							= N'CALL sp_MSdel_dbotest_table_01'
                         , @upd_cmd							= N'SCALL sp_MSupd_dbotest_table_01';
GO


USE [test_db]
GO

INSERT INTO [dbo].[test_table_01]
           ([dt]
           ,[a]
           ,[b])
     VALUES
           (GETDATE()
           ,888
           ,999)
GO


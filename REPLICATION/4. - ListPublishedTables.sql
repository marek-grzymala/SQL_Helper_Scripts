USE [test_db];
GO

SELECT [ss].[name] AS [sch_name]
     , [st].[name] AS [tbl_name]
     , [st].[schema_id]
     , [st].[object_id]
     , [st].[is_published]
     , [st].[is_merge_published]
     , [st].[is_schema_published]
FROM [sys].[tables] AS [st]
JOIN [sys].[schemas] AS [ss]
    ON [ss].[schema_id] = [st].[schema_id]
WHERE [st].[is_published] = 1
OR    [st].[is_merge_published] = 1
OR    [st].[is_schema_published] = 1;
GO

SELECT [name]
     , [object_id]
     , [principal_id]
     , [schema_id]
     , [parent_object_id]
     , [is_ms_shipped]
     , [is_published]
     , [is_schema_published]
	 , [is_replicated]
	 , [has_replication_filter]
	 , [is_merge_published]
	 , [is_sync_tran_subscribed]
FROM [sys].[tables]
WHERE [is_replicated] = 1;

SELECT [dest_table] AS [SubscriberTable]
     , [name] AS [ArticleName]
     , [dest_owner] AS [ArticleSchema]
     , [objid]
     , [artid]
     , [creation_script]
     , [del_cmd]
     , [description]
     , [dest_table]
     , [filter]
     , [filter_clause]
     , [ins_cmd]
     , [name]
     , [objid]
     , [pubid]
     , [pre_creation_cmd]
     , [status]
     , [sync_objid]
     , [type]
     , [upd_cmd]
     , [schema_option]
     , [dest_owner]
     , [ins_scripting_proc]
     , [del_scripting_proc]
     , [upd_scripting_proc]
     , [custom_script]
     , [fire_triggers_on_snapshot]
FROM [dbo].[sysarticles];

											-- parameters in [sys].[sp_addpublication]:
SELECT [description]						-- @description 
     , [name]								-- @publication
     , [pubid]
     , [repl_freq]							-- @repl_freq:
											/*
											0 = continuous
											1 = snapshot
											*/
     , [status]								-- @status
     , [sync_method]						-- @sync_method:
											/*
											0 = native,			bulk-copy program utility (BCP).
											1 = character,		BCP.
											3 = concurrent,		which means that native-mode BCP is used but tables are not locked during the snapshot.
											4 = concurrent_c,	which means that character-mode BCP is used but tables are not locked during the snapshot.
											*/
     , [snapshot_jobid]
     , [independent_agent]
     , [immediate_sync]						-- @immediate_sync
     , [enabled_for_internet]				-- @enabled_for_internet
     , [allow_push]							-- @allow_push
     , [allow_pull]							-- @allow_pull
     , [allow_anonymous]					-- @allow_anonymous
     , [immediate_sync_ready]				
     , [allow_sync_tran]					-- @allow_sync_tran
     , [autogen_sync_procs]					-- @autogen_sync_procs
     , [retention]							-- @retention
     , [allow_queued_tran]					-- @allow_queued_tran
     , [snapshot_in_defaultfolder]			-- @snapshot_in_defaultfolder
     , [alt_snapshot_folder]
     , [pre_snapshot_script]				
     , [post_snapshot_script]
     , [compress_snapshot]					-- @compress_snapshot
     , [ftp_address]
     , [ftp_port]							-- @ftp_port
     , [ftp_subdirectory]
     , [ftp_login]							-- @ftp_login
     , [ftp_password]
     , [allow_dts]
     , [allow_subscription_copy]
     , [centralized_conflicts]
     , [conflict_retention]
     , [conflict_policy]
     , [queue_type]
     , [ad_guidname]
     , [backward_comp_level]
     , [allow_initialize_from_backup]
     , [min_autonosync_lsn]
     , [replicate_ddl]
     , [options]
     , [originator_id]

FROM [dbo].[syspublications];

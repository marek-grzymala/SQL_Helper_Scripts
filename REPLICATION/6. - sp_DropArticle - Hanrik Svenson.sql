/*
source: https://www.sqlteam.com/forums/topic.asp?TOPIC_ID=128275

Template script for making DDL changes to ONE article in ONE publication.

The template code retreives the article properties and stores them in a temporary table
and then re-adds the article to its publication after the DDL changes have been applied.
The DDL changes need to be added manually.

Instructions:
- Locate the row starting with "SET @TableName = 'tableName'" and set the table name.
- Add code with DDL changes in the "Put your DDL changes here" section.

NOTE:
This script will not work if the same table is included as an article in several publications.
This script will not work if column level filters are set on the article.
This script will not work if the article name and table name differ.

*/

SET NOCOUNT ON;

IF EXISTS (SELECT * FROM [tempdb]..[sysobjects] WHERE [name] LIKE '#helparticle%' AND [type] = 'U')
    DROP TABLE [#helparticle];
GO

IF EXISTS (SELECT * FROM [tempdb]..[sysobjects] WHERE [name] LIKE '#helppublication%' AND [type] = 'U')
    DROP TABLE [#helppublication];
GO

CREATE TABLE [#helppublication]
(
    [pubid]                             INT
  , [name]                              NVARCHAR(128)
  , [restricted]                        INT
  , [status]                            TINYINT
  , [task]                              INT
  , [replication frequency]             TINYINT
  , [synchronization method]            TINYINT
  , [description]                       NVARCHAR(255)
  , [immediate_sync]                    BIT
  , [enabled_for_internet]              BIT
  , [allow_push]                        BIT
  , [allow_pull]                        BIT
  , [allow_anonymous]                   BIT
  , [independent_agent]                 BIT
  , [immediate_sync_ready]              BIT
  , [allow_sync_tran]                   BIT
  , [autogen_sync_procs]                BIT
  , [snapshot_jobid]                    BINARY(16)
  , [retention]                         INT
  , [has subscription]                  INT
  , [allow_queued_tran]                 BIT
  , [snapshot_in_defaultfolder]         BIT
  , [alt_snapshot_folder]               NVARCHAR(255)
  , [pre_snapshot_script]               NVARCHAR(255)
  , [post_snapshot_script]              NVARCHAR(255)
  , [compress_snapshot]                 BIT
  , [ftp_address]                       NVARCHAR(128)
  , [ftp_port]                          INT
  , [ftp_subdirectory]                  NVARCHAR(255)
  , [ftp_login]                         NVARCHAR(128)
  , [allow_dts]                         BIT
  , [allow_subscription_copy]           BIT
  , [centralized_conflicts]             BIT
  , [conflict_retention]                INT
  , [conflict_policy]                   INT
  , [queue_type]                        INT
  , [backward_comp_level]               INT
  , [publish_to_AD]                     INT
  , [allow_initialize_from_backup]      BIT
  , [replicate_ddl]                     INT
  , [enabled_for_p2p]                   INT
  , [publish_local_changes_only]        INT
  , [enabled_for_het_sub]               INT
  , [enabled_for_p2p_conflictdetection] INT
  , [originator_id]                     INT
  , [p2p_continue_onconflict]           INT
  , [allow_partition_switch]            INT
  , [replicate_partition_switch]        INT
  , [allow_drop]                        INT
);

CREATE TABLE [#helparticle]
(
    [article id]                    INT           PRIMARY KEY CLUSTERED
  , [article name]                  sysname       NULL
  , [base object]                   NVARCHAR(257) NULL
  , [destination object]            sysname       NULL
  , [synchronization object]        NVARCHAR(257) NULL
  , [type]                          SMALLINT      NULL
  , [status]                        TINYINT       NULL
  , [filter]                        NVARCHAR(257) NULL
  , [description]                   NVARCHAR(255) NULL
  , [insert_command]                NVARCHAR(255) NULL
  , [update_command]                NVARCHAR(255) NULL
  , [delete_command]                NVARCHAR(255) NULL
  , [creation script path]          NVARCHAR(255) NULL
  , [vertical partition]            BIT           NULL
  , [pre_creation_cmd]              TINYINT       NULL
  , [filter_clause]                 NTEXT         NULL
  , [schema_option]                 BINARY(8)     NULL
  , [dest_owner]                    sysname       NULL
  , [source_owner]                  sysname       NULL
  , [unqua_source_object]           sysname       NULL
  , [sync_object_owner]             sysname       NULL
  , [unqualified_sync_object]       sysname       NULL
  , [filter_owner]                  sysname       NULL
  , [unqua_filter]                  sysname       NULL
  , [auto_identity_range]           INT           NULL
  , [publisher_identity_range]      INT           NULL
  , [identity_range]                BIGINT        NULL
  , [threshold]                     BIGINT        NULL
  , [identityrangemanagementoption] INT           NULL
  , [fire_triggers_on_snapshot]     BIT           NULL
  , [publication_name]				SYSNAME		  NULL
  , [article_dropped]				BIT			  NULL
);
GO

DECLARE @TableName sysname;
DECLARE @TableIsPublished BIT;
DECLARE @TableId INT;

SET @TableName = 'test_table_01'; -- set name of table that needs to be removed from, modified, and then added to publication (if published).

SELECT @TableIsPublished = [is_published]
     , @TableId = [object_id]
FROM [sys].[objects]
WHERE [name] = @TableName
AND   [type] = 'U';



IF @TableIsPublished = 1
BEGIN
    DECLARE @creation_script NVARCHAR(255);
    DECLARE @del_cmd NVARCHAR(255);
    DECLARE @description NVARCHAR(255);
    DECLARE @dest_table sysname;
    DECLARE @filter INT;
    DECLARE @filter_clause sysname;
    DECLARE @ins_cmd NVARCHAR(255);
    DECLARE @name sysname;
    DECLARE @objid INT;
    DECLARE @pubid INT;
    DECLARE @pre_creation_cmd TINYINT;
    DECLARE @status TINYINT;
    DECLARE @sync_objid INT;
    DECLARE @type TINYINT;
    DECLARE @upd_cmd NVARCHAR(255);
    DECLARE @schema_option BINARY(8);
    DECLARE @dest_owner sysname;
    DECLARE @ins_scripting_proc INT;
    DECLARE @del_scripting_proc INT;
    DECLARE @upd_scripting_proc INT;
    DECLARE @custom_script NVARCHAR(2048);
    DECLARE @fire_triggers_on_snapshot_bit BIT;
    DECLARE @fire_triggers_on_snapshot_nvarchar5 NVARCHAR(5);

    DECLARE @PublicationName sysname;
    SELECT @PublicationName = [syspub].[name]
    FROM [dbo].[sysarticles] [sysart]
    INNER JOIN [dbo].[syspublications] [syspub]
        ON [sysart].[pubid] = [syspub].[pubid]
    WHERE [sysart].[objid] = @TableId;

    INSERT INTO [#helparticle]
        (
            [article id]
          , [article name]
          , [base object]
          , [destination object]
          , [synchronization object]
          , [type]
          , [status]
          , [filter]
          , [description]
          , [insert_command]
          , [update_command]
          , [delete_command]
          , [creation script path]
          , [vertical partition]
          , [pre_creation_cmd]
          , [filter_clause]
          , [schema_option]
          , [dest_owner]
          , [source_owner]
          , [unqua_source_object]
          , [sync_object_owner]
          , [unqualified_sync_object]
          , [filter_owner]
          , [unqua_filter]
          , [auto_identity_range]
          , [publisher_identity_range]
          , [identity_range]
          , [threshold]
          , [identityrangemanagementoption]
          , [fire_triggers_on_snapshot]
        )
	EXEC [sys].[sp_helparticle] @PublicationName, @TableName;
	UPDATE [#helparticle] SET [publication_name] = @PublicationName, [article_dropped] = 0;

    INSERT INTO [#helppublication]
        (
            [pubid]
          , [name]
          , [restricted]
          , [status]
          , [task]
          , [replication frequency]
          , [synchronization method]
          , [description]
          , [immediate_sync]
          , [enabled_for_internet]
          , [allow_push]
          , [allow_pull]
          , [allow_anonymous]
          , [independent_agent]
          , [immediate_sync_ready]
          , [allow_sync_tran]
          , [autogen_sync_procs]
          , [snapshot_jobid]
          , [retention]
          , [has subscription]
          , [allow_queued_tran]
          , [snapshot_in_defaultfolder]
          , [alt_snapshot_folder]
          , [pre_snapshot_script]
          , [post_snapshot_script]
          , [compress_snapshot]
          , [ftp_address]
          , [ftp_port]
          , [ftp_subdirectory]
          , [ftp_login]
          , [allow_dts]
          , [allow_subscription_copy]
          , [centralized_conflicts]
          , [conflict_retention]
          , [conflict_policy]
          , [queue_type]
          , [backward_comp_level]
          , [publish_to_AD]
          , [allow_initialize_from_backup]
          , [replicate_ddl]
          , [enabled_for_p2p]
          , [publish_local_changes_only]
          , [enabled_for_het_sub]
          , [enabled_for_p2p_conflictdetection]
          , [originator_id]
          , [p2p_continue_onconflict]
          , [allow_partition_switch]
          , [replicate_partition_switch]
          , [allow_drop]
        )
	EXEC [sys].[sp_helppublication] @PublicationName
END;

SELECT * FROM [#helparticle]
SELECT * FROM [#helppublication]

select  
db_name() PublisherDB 
, sp.name as PublisherName 
, sa.name as TableName 
, UPPER(srv.srvname) as SubscriberServerName 
from dbo.syspublications sp  
LEFT join dbo.sysarticles sa on sp.pubid = sa.pubid 
LEFT join dbo.syssubscriptions s on sa.artid = s.artid 
LEFT join master.dbo.sysservers srv on s.srvid = srv.srvid

SELECT DISTINCT 
       PublisherDB,
       PublisherName,
       SubscriberServerName,
       SubscriberDBName
       FROM (
                select  
                db_name() PublisherDB 
                , sp.name as PublisherName 
                , sa.name as TableName 
                , UPPER(srv.srvname) as SubscriberServerName 
                , s.dest_db as SubscriberDBName
                from dbo.syspublications sp  
                left join dbo.sysarticles sa on sp.pubid = sa.pubid 
                left join dbo.syssubscriptions s on sa.artid = s.artid 
                left join master.dbo.sysservers srv on s.srvid = srv.srvid 
             ) R

GO


IF EXISTS (SELECT * FROM [#helparticle])
BEGIN
    DECLARE @PublicationName sysname;
    DECLARE @TableId INT;
    DECLARE @TableName sysname;

    SELECT @PublicationName = [publication_name] FROM [#helppublication];
    SELECT @TableId = [table_id] FROM [#helppublication];
    SELECT @TableName = [name] FROM [sys].[objects] WHERE [object_id] = @TableId;

    UPDATE [#helparticle] SET [publication_name] = @PublicationName, [article_dropped] = 0;

    IF EXISTS (
                  SELECT *
                  FROM [dbo].[syssubscriptions] [syssub]
                  INNER JOIN [dbo].[sysarticles] [sysart]
                      ON [sysart].[artid] = [syssub].[artid]
                  WHERE [sysart].[objid] = @TableId
              )
    BEGIN
        PRINT 'Table "' + @TableName + '" is included in publication "' + @PublicationName + '" that has at least one subscriber. Drop subscription(s) manually, then re-run this script.';
        UPDATE [#helparticle] SET [article_dropped] = 0;
    END;
    ELSE
    BEGIN
        PRINT 'Dropping article ' + @TableName + '.';
        EXEC [sys].[sp_droparticle] 
					@publication = N'test_db_pub_a' --@PublicationName
				  , @article = N'test_table_01' --@TableName;
        UPDATE [#helparticle] SET [article_dropped] = 1;
    END;
END;
GO

----------------------------------------------------------
-- Put your DDL changes here (and other changes, e.g. code to temporary store data to add after table changes have been applied).

-- IMPORTANT: Check if article was dropped within EACH batch by using "IF EXISTS (SELECT * FROM #helparticle WHERE article_dropped = 1) OR NOT EXISTS (SELECT * FROM #helparticle) BEGIN [...] END"



----------------------------------------------------------

--- Add article again:
DECLARE @publication_name sysname;
DECLARE @type sysname;
DECLARE @article sysname;
DECLARE @destination_table sysname;
DECLARE @source_object sysname;
DECLARE @vertical_partition NVARCHAR(5);
DECLARE @filter NVARCHAR(257);
DECLARE @sync_object NVARCHAR(257);
DECLARE @ins_cmd NVARCHAR(255);
DECLARE @upd_cmd NVARCHAR(255);
DECLARE @del_cmd NVARCHAR(255);
DECLARE @creation_script NVARCHAR(255);
DECLARE @pre_creation_cmd NVARCHAR(10);
DECLARE @filter_clause NVARCHAR(MAX);
DECLARE @schema_option BINARY(8);
DECLARE @destination_owner sysname;
DECLARE @status TINYINT;
DECLARE @source_owner sysname;
DECLARE @sync_object_owner sysname;
DECLARE @filter_owner sysname;
DECLARE @auto_identity_range NVARCHAR(5);
DECLARE @pub_identity_range BIGINT;
DECLARE @identity_range BIGINT;
DECLARE @threshold BIGINT;
DECLARE @force_invalidate_snapshot BIT;
DECLARE @use_default_datatypes BIT;
DECLARE @identityrangemanagementoption NVARCHAR(10);
DECLARE @publisher sysname;
DECLARE @fire_triggers_on_snapshot NVARCHAR(5);
DECLARE @description NVARCHAR(255);

IF EXISTS (SELECT * FROM [#helparticle] WHERE [article_dropped] = 1)
BEGIN

    SELECT @publication_name = [publication_name]
         , @article = [article name]
         , @destination_table = [destination object]
         , @source_object = [unqua_source_object]
         , @filter = [filter]
         , @description = @description
                                          --special case: this variable should be NULL if sync_object was automatically created, which will give it the prefix "syncobj_", so we look for that string on the line below:
         , @sync_object = CASE
                              WHEN [synchronization object] IS NOT NULL THEN CASE
                                                                                 WHEN CHARINDEX('syncobj_', [synchronization object]) <> 0 THEN NULL
                                                                                 ELSE [synchronization object]
                                                                             END
                              ELSE [synchronization object]
                          END
         , @ins_cmd = [insert_command]
         , @upd_cmd = [update_command]
         , @del_cmd = [delete_command]
         , @creation_script = [creation script path]
         , @filter_clause = [filter_clause]
         , @schema_option = [schema_option]
         , @destination_owner = [dest_owner]
         , @status = [status]
         , @source_owner = [source_owner]
         , @pub_identity_range = [publisher_identity_range]
         , @identity_range = [identity_range]
         , @threshold = [threshold]
         , @force_invalidate_snapshot = 1 --in this case we have already dropped the subscriptions, so there must be a new snapshot in any case.
         , @use_default_datatypes = 1     --only of interest when publishing from Oracle
         , @publisher = NULL              --we only use SQL Servers as publishers, so this parameter should be set to NULL.
    FROM [#helparticle];

    IF NOT @sync_object IS NULL
        SELECT @sync_object_owner = [sync_object_owner] FROM [#helparticle];
    ELSE
        SET @sync_object_owner = NULL;

    IF NOT @filter IS NULL
        SELECT @filter_owner = [filter_owner] FROM [#helparticle];
    ELSE
        SET @filter_owner = NULL;

    IF 1 = (SELECT [vertical partition] FROM [#helparticle])
        SET @vertical_partition = N'true';
    ELSE
        SET @vertical_partition = N'false';

    IF 1 = (SELECT [fire_triggers_on_snapshot] FROM [#helparticle])
        SET @fire_triggers_on_snapshot = N'true';
    ELSE
        SET @fire_triggers_on_snapshot = N'false';

    SELECT @type = CASE
                       WHEN [type] = 1 THEN 'logbased'
                       WHEN [type] = 3 THEN 'logbased manualfilter'
                       WHEN [type] = 5 THEN 'logbased manualview'
                       WHEN [type] = 7 THEN 'logbased manualboth'
                       WHEN [type] = 8 THEN 'proc exec'
                       WHEN [type] = 24 THEN 'serializable proc exec'
                       WHEN [type] = 32 THEN 'proc schema only'
                       WHEN [type] = 64 THEN 'view schema only'
                       WHEN [type] = 128 THEN 'func schema only'
                       ELSE 'logbased' --default
                   END
    FROM [#helparticle];

    SELECT @pre_creation_cmd = CASE
                                   WHEN [pre_creation_cmd] = 0 THEN 'none'
                                   WHEN [pre_creation_cmd] = 1 THEN 'delete'
                                   WHEN [pre_creation_cmd] = 2 THEN 'drop'
                                   WHEN [pre_creation_cmd] = 3 THEN 'truncate'
                                   ELSE 'drop' --default
                               END
    FROM [#helparticle];

    SELECT @auto_identity_range = CASE
                                      WHEN [auto_identity_range] = 1 THEN 'true'
                                      WHEN [auto_identity_range] = 0 THEN 'false'
                                      ELSE NULL
                                  END
    FROM [#helparticle];

    SELECT @identityrangemanagementoption = CASE
                                                WHEN [identityrangemanagementoption] = 0 THEN 'none'
                                                WHEN [identityrangemanagementoption] = 1 THEN 'manual'
                                                WHEN [identityrangemanagementoption] = 2 THEN 'auto'
                                                ELSE NULL --default
                                            END
    FROM [#helparticle];

    PRINT 'Adding article ' + @article + '.';

    EXEC [sys].[sp_addarticle] @publication = @publication_name
                             , @article = @article
                             , @source_table = NULL --do not use, use source_object instead
                             , @destination_table = @destination_table
                             , @vertical_partition = @vertical_partition
                             , @type = @type
                             , @filter = @filter
                             , @sync_object = @sync_object
                             , @ins_cmd = @ins_cmd
                             , @del_cmd = @del_cmd
                             , @upd_cmd = @upd_cmd
                             , @creation_script = @creation_script
                             , @description = @description
                             , @pre_creation_cmd = @pre_creation_cmd
                             , @filter_clause = @filter_clause
                             , @schema_option = @schema_option
                             , @destination_owner = @destination_owner
                             , @status = @status
                             , @source_owner = @source_owner
                             , @sync_object_owner = @sync_object_owner
                             , @filter_owner = @filter_owner
                             , @source_object = @source_object
                             , @artid = NULL
                             , @auto_identity_range = @auto_identity_range
                             , @pub_identity_range = @pub_identity_range
                             , @identity_range = @identity_range
                             , @threshold = @threshold
                             , @force_invalidate_snapshot = @force_invalidate_snapshot
                             , @use_default_datatypes = @use_default_datatypes
                             , @identityrangemanagementoption = @identityrangemanagementoption
                             , @publisher = @publisher
                             , @fire_triggers_on_snapshot = @fire_triggers_on_snapshot;

END;

IF EXISTS (SELECT * FROM [tempdb]..[sysobjects] WHERE [name] LIKE '#helparticle%' AND [type] = 'U')
    DROP TABLE [#helparticle];
GO

IF EXISTS (SELECT * FROM [tempdb]..[sysobjects] WHERE [name] LIKE '#helppublication%' AND [type] = 'U')
    DROP TABLE [#helppublication];
GO

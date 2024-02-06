USE [test_db]
GO

/*
 This stored procedure is executed at the Publisher on the publication database:
*/

sp_changepublication @publication = N'test_db_pub_a'
    , @property = N'status'  
    , @value = N'inactive'  

SELECT msd.distribution_db,
	msd.publisher_type,
	ss.srvid,
	msd.working_directory,
	@@microsoftversion
	FROM msdb.dbo.MSdistpublishers as msd join dbo.MSreplservers ss 
	ON msd.name = UPPER(ss.srvname collate database_default )
	--AND msd.name = @P_publisher

SELECT @@microsoftversion


SELECT	DISTINCT 
		[art].[artid]
      , [art].[creation_script]
      , [art].[del_cmd]
      , [art].[description]
      , [art].[dest_table]
      , [art].[filter]
      , [art].[filter_clause]
      , [art].[ins_cmd]
      , [art].[name]
      , [art].[objid]
      , [art].[pubid]
      , [art].[pre_creation_cmd]
      , [art].[status]
      , [art].[sync_objid]
      , [art].[type]
      , [art].[upd_cmd]
      , [art].[schema_option]
      , [art].[dest_owner]
      , [art].[ins_scripting_proc]
      , [art].[del_scripting_proc]
      , [art].[upd_scripting_proc]
      , [art].[custom_script]
      , [art].[fire_triggers_on_snapshot]
		, sub.*
		, pub.*
FROM	[dbo].[sysarticles] art,
		[dbo].[sysextendedarticlesview] xart,
		[dbo].[syssubscriptions] sub,
		[dbo].[syspublications] pub
--WHERE	 ((sub.srvname is not null and len(sub.srvname) > 0 and sub.srvname = UPPER(@subscriber)  )
--		or ((sub.srvname is null or len(sub.srvname) = 0 )and sub.srvid = @virtual_id))
		-- @destination_db will not be expanded before @article is expanded.
  --AND	(
		--	((@destination_db = N'%') OR (sub.dest_db = @destination_db))   OR
		--	@destination_db IS NULL         OR
		--	LOWER(@destination_db) = 'all'
		--)
  WHERE 1 = 1
  AND	art.artid = sub.artid
  AND	art.pubid = pub.pubid
  AND	xart.artid = sub.artid
  AND	xart.pubid = pub.pubid
  --AND	pub.pubid = @pubid
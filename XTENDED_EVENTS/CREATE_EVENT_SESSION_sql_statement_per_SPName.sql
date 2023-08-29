CREATE EVENT SESSION [TrackProcedure] ON SERVER 
ADD EVENT sqlserver.module_start(SET collect_statement=(1)
    ACTION(	sqlserver.client_app_name
			,sqlserver.database_name
			,sqlserver.session_server_principal_name
			,sqlserver.sql_text
			,sqlserver.tsql_stack
			,sqlserver.username
		  )
    WHERE ([object_type] = 'P ' AND [object_name] = N'sp_name'))
WITH (
		 MAX_MEMORY=4096 KB
		,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
		,MAX_DISPATCH_LATENCY=30 SECONDS
		,MAX_EVENT_SIZE=0 KB
		,MEMORY_PARTITION_MODE=NONE
		,TRACK_CAUSALITY=OFF
		,STARTUP_STATE=OFF
	)
GO
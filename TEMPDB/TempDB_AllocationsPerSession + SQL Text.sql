USE [tempdb]
GO
    
SELECT SUM(unallocated_extent_page_count) AS [free pages], 
(SUM(unallocated_extent_page_count)*1.0/128) AS [free space in MB]
FROM sys.dm_db_file_space_usage;



SELECT 
	es.session_id,
	es.login_name AS 'LoginName',
	DB_NAME(ssu.database_id) AS 'DatabaseName',
	(es.memory_usage * 8) AS 'MemoryUsage (in KB)',
	(ssu.user_objects_alloc_page_count * 8) AS 'Space Allocated For User Objects (in KB)',
	(ssu.user_objects_dealloc_page_count * 8) AS 'Space Deallocated For User Objects (in KB)',
	(ssu.user_objects_alloc_page_count - ssu.user_objects_alloc_page_count) * 8 AS 'User Objects Not-released (in KB)',
	(ssu.internal_objects_alloc_page_count * 8) AS 'Space Allocated For Internal Objects (in KB)',
	(ssu.internal_objects_dealloc_page_count * 8) AS 'Space Deallocated For Internal Objects (in KB)',
	(ssu.internal_objects_alloc_page_count - ssu.internal_objects_dealloc_page_count) * 8 AS 'Internal Objects Not-released (in KB)',

	es.cpu_time AS [CPU TIME (in milisec)],
	es.total_scheduled_time AS [Total Scheduled TIME (in milisec)],
	es.total_elapsed_time AS    [Elapsed TIME (in milisec)],

	CASE es.is_user_process
		WHEN 1 THEN 'User Session'
		WHEN 0 THEN 'System Session'
	END AS 'SessionType',
	es.row_count AS 'RowCount',
	st.text

FROM sys.dm_db_session_space_usage ssu
	INNER JOIN sys.dm_exec_sessions es ON ssu.session_id = es.session_id
	INNER JOIN sys.dm_exec_connections er ON ssu.session_id = er.session_id
	CROSS APPLY sys.dm_exec_sql_text(er.most_recent_sql_handle) st
WHERE 
	DB_NAME(ssu.database_id) = 'tempdb'
	AND es.session_id <> @@SPID
	AND es.login_name NOT IN ('sa')
    AND es.session_id = 118
ORDER BY
	[Internal Objects Not-released (in KB)] DESC
	--[User Objects Not-released (in KB)] DESC,
	--es.total_scheduled_time DESC




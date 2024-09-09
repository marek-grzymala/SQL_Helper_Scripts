SELECT [R].[session_id]
     , [T].[text]
     , [R].[status]
     , [R].[command]
     , [DatabaseName] = DB_NAME([R].[database_id])
     , [R].[cpu_time]
     , [R].[total_elapsed_time]
     , [R].[percent_complete]
FROM sys.dm_exec_requests [R]
CROSS APPLY sys.dm_exec_sql_text([R].[sql_handle]) [T];
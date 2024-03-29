;WITH CTE
AS (SELECT (SUM(unallocated_extent_page_count) / 128) AS FreeSpace,
           SUM(internal_object_reserved_page_count) / 128 AS IntObj,
           SUM(user_object_reserved_page_count) / 128 AS UserObj,
           SUM(version_store_reserved_page_count) / 128 AS VersionStore
    FROM tempdb.sys.dm_db_file_space_usage
    --database_id '2' represents tempdb
    WHERE database_id = 2)
SELECT MAX(SUBSTRING(
                        st.text,
                        dmv_er.statement_start_offset / 2 + 1,
                        (CASE
                             WHEN dmv_er.statement_end_offset = -1 THEN
                                 LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                             ELSE
                                 dmv_er.statement_end_offset
                         END - dmv_er.statement_start_offset
                        ) / 2
                    )
          ) AS Query_Text,
       dmv_tsu.session_id,
       (SUM((dmv_tsu.user_objects_alloc_page_count - dmv_tsu.user_objects_dealloc_page_count) / 128)
        + SUM((dmv_tsu.internal_objects_alloc_page_count - dmv_tsu.internal_objects_dealloc_page_count) / 128)
       ) AS UsedTempDbMB,
       MAX(dmv_er.start_time) AS start_time,
       SUM(dmv_er.open_transaction_count) AS open_transaction_count,
       MAX(dmv_es.host_name) AS host_name,
       MAX(dmv_es.login_name) AS login_name,
       MAX(dmv_es.program_name) AS program_name
FROM sys.dm_db_task_space_usage dmv_tsu
    INNER JOIN sys.dm_exec_requests dmv_er
        ON (
               dmv_tsu.session_id = dmv_er.session_id
               AND dmv_tsu.request_id = dmv_er.request_id
           )
    INNER JOIN sys.dm_exec_sessions dmv_es
        ON (dmv_tsu.session_id = dmv_es.session_id)
    CROSS APPLY sys.dm_exec_sql_text(dmv_er.sql_handle) st
WHERE (dmv_tsu.internal_objects_alloc_page_count + dmv_tsu.user_objects_alloc_page_count) > 0
GROUP BY dmv_tsu.session_id
UNION ALL
SELECT NULL AS QueryText,
       -1 AS session_id,
       CTE.FreeSpace AS UsedTempDB,
       NULL AS start_time,
       NULL AS open_transaction_count,
       @@SERVERNAME AS host_name,
       'SYSTEM' AS login_name,
       'Remaining TempDB space' AS program_name
FROM CTE
UNION ALL
SELECT NULL AS QueryText,
       -2 AS session_id,
       CTE.VersionStore AS UsedTempDB,
       NULL AS start_time,
       NULL AS open_transaction_count,
       @@SERVERNAME AS host_name,
       'SYSTEM' AS login_name,
       'Used Version Store space' AS program_name
FROM CTE;

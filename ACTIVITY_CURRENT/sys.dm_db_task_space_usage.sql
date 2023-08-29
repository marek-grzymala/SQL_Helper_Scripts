SELECT TOP 10
       tsu.session_id,
       tsu.request_id,
       r.command,
       s.login_name,
       s.host_name,
       s.program_name,
       total_objects_alloc_page_count = tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count,
       tsu.user_objects_alloc_page_count,
       tsu.user_objects_dealloc_page_count,
       tsu.internal_objects_alloc_page_count,
       tsu.internal_objects_dealloc_page_count,
       st.text
FROM sys.dm_db_task_space_usage tsu
    INNER JOIN sys.dm_exec_requests r
        ON tsu.session_id = r.session_id
           AND tsu.request_id = r.request_id
    INNER JOIN sys.dm_exec_sessions s
        ON r.session_id = s.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE 1 = 1
      AND tsu.session_id > 50
      AND
      (
          tsu.user_objects_alloc_page_count > 0
          OR tsu.internal_objects_alloc_page_count > 0
      )
ORDER BY total_objects_alloc_page_count DESC;
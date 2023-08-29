-- Simple query for how to query the System_health session file.
SELECT CAST(event_data AS xml), timestamp_utc
FROM sys.fn_xe_file_target_read_file(
     N'system_health*.xel', DEFAULT, DEFAULT, DEFAULT)
WHERE object_name = 'xml_deadlock_report'
ORDER BY timestamp_utc DESC

-- Somewhat more sophisticated, the X-events tags are stripped out.
; WITH CTE AS (
  SELECT CAST(event_data AS xml) AS xml, timestamp_utc
  FROM sys.fn_xe_file_target_read_file(
     N'system_health*.xel', DEFAULT, DEFAULT, DEFAULT)
  WHERE object_name = 'xml_deadlock_report'
)
SELECT xml.query('/event/data[1]/value[1]/deadlock[1]'), timestamp_utc
FROM   CTE
ORDER BY timestamp_utc DESC

-- This query is for SQL 2016 and earlier where the timestamp_utc column
-- is not available. Can be slow.
; WITH CTE AS (
  SELECT CAST(event_data AS xml) AS xml
  FROM sys.fn_xe_file_target_read_file(
     N'system_health*.xel', DEFAULT, DEFAULT, DEFAULT)
  WHERE object_name = 'xml_deadlock_report'
)
SELECT xml.query('/event/data[1]/value[1]/deadlock[1]'), 
       xml.value('/event[1]/@timestamp', 'datetime2(3)') AS timestamp_utc
FROM   CTE
ORDER BY timestamp_utc DESC


-- This query goes against the ring buffer for the system_health session.
-- I have found this one to be less useful. Since it's a ring buffer, events
-- can fall off before you get to look for a certain deadlock. At the same
-- the latency can be significant. However, this is the only way to access
-- system_health on Azure Managed Instance.
; WITH CTE AS (
   SELECT data = CAST(st.target_data AS XML) 
   FROM   sys.dm_xe_session_targets AS st
   JOIN   sys.dm_xe_sessions AS s ON s.address = st.event_session_address
   WHERE  s.name = N'system_health'
     AND  st.target_name = N'ring_buffer'
)
SELECT D.d.query('data[1]/value[1]/deadlock[1]') AS Deadlock,
       D.d.value('@timestamp', 'datetime2(3)') as timestamp_utc
FROM   CTE
CROSS  APPLY data.nodes(
        '/RingBufferTarget/event[@name="xml_deadlock_report"]') AS D(d)
ORDER BY timestamp_utc DESC


-- Query to use if you use a dedicated X-events session. You need the
-- path when the file is not in the default folder.
; WITH CTE AS (
  SELECT CAST(event_data AS xml) AS xml, timestamp_utc
  FROM sys.fn_xe_file_target_read_file(
     N'C:\Temp\deadlocks*.xel', DEFAULT, DEFAULT, DEFAULT)
)
SELECT xml.query('/event/data[1]/value[1]/deadlock[1]'), timestamp_utc
FROM   CTE
ORDER BY timestamp_utc DESC

-- This query is for Azure SQL Database (not Azure Managed Instance!)
-- Note that you need to run this from the master database!
; WITH CTE AS (
  SELECT CAST(event_data AS xml) AS xml, timestamp_utc
  FROM sys.fn_xe_telemetry_blob_target_read_file(
      'dl', NULL, NULL, NULL)
)
SELECT timestamp_utc, xml.query(
      '/event/data[@name="xml_report"]/value/deadlock'), xml.query('.')
FROM   CTE
WHERE  xml.exist('/event/data[@name="database_name"]/ value[.="YourDBHere"]') = 1
ORDER BY timestamp_utc DESC


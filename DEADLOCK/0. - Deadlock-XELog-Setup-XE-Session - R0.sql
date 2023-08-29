DECLARE @temp_store TABLE ([temp_value_name] VARCHAR(255), [temp_value] VARCHAR(255));
DECLARE @subkey   NVARCHAR(2000)
      , @filename NVARCHAR(2000)
	  , @filepath NVARCHAR(2000)
	  , @sql NVARCHAR(MAX);
SET @subkey = N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\Parameters';
SET @filename = N'deadlock_capture.xel'

SET @filepath = N'C:\MSSQL\Backup\';
/* set @filepath to your own path if you want to place event log in your own path: 

;WITH xeTargets
AS
(
    SELECT
        s.name
        , t.target_name
        , CAST(t.target_data AS xml) AS xmlData
    FROM
        sys.dm_xe_session_targets AS t
        JOIN sys.dm_xe_sessions AS s
            ON s.address = t.event_session_address
)
SELECT
    xt.name
    , xt.target_name
    , xNodes.xNode.value('@name', 'varchar(250)') AS filePath
    , xt.xmlData
FROM xeTargets AS xt
CROSS APPLY xt.xmlData.nodes('.//File') xNodes (xNode) /* OUTER APPLY if you want to see other sessions */
WHERE xNodes.xNode.value('@name', 'varchar(250)') IS NOT NULL; --xt.name = 'system_health'
*/

IF (@filepath IS NULL)
BEGIN
    INSERT @temp_store EXEC [master]..[xp_instance_regenumvalues] @rootkey = N'HKEY_LOCAL_MACHINE', @key = @subkey;
    SELECT @filepath = SUBSTRING([temp_value], 3, LEN([temp_value]) - CHARINDEX('\', REVERSE([temp_value])) - 1)
    FROM @temp_store
    WHERE SUBSTRING([temp_value], 1, 2) = '-e';
END;

SET @sql = CONCAT('

CREATE EVENT SESSION [deadlock_capture]
ON SERVER
    ADD EVENT [sqlserver].[database_xml_deadlock_report]
    (ACTION (
                [sqlserver].[database_id]
              , [sqlserver].[nt_username]
              , [sqlserver].[session_id]
              , [sqlserver].[sql_text]
              , [sqlserver].[transaction_id]
              , [sqlserver].[transaction_sequence]
              , [sqlserver].[username]
            )
    )
  , ADD EVENT [sqlserver].[lock_deadlock]
    (ACTION (
                [sqlserver].[database_id]
              , [sqlserver].[nt_username]
              , [sqlserver].[session_id]
              , [sqlserver].[sql_text]
              , [sqlserver].[transaction_id]
              , [sqlserver].[transaction_sequence]
              , [sqlserver].[username]
            )
    )
  , ADD EVENT [sqlserver].[lock_deadlock_chain]
    (ACTION (
                [sqlserver].[database_id]
              , [sqlserver].[nt_username]
              , [sqlserver].[session_id]
              , [sqlserver].[sql_text]
              , [sqlserver].[transaction_id]
              , [sqlserver].[transaction_sequence]
              , [sqlserver].[username]
            )
    )
  , ADD EVENT [sqlserver].[xml_deadlock_report]
    (ACTION (
                [sqlserver].[database_id]
              , [sqlserver].[nt_username]
              , [sqlserver].[session_id]
              , [sqlserver].[sql_text]
              , [sqlserver].[transaction_id]
              , [sqlserver].[transaction_sequence]
              , [sqlserver].[username]
            )
    )
    ADD TARGET [package0].[event_file]
    (SET filename = N''', @filepath, @filename, ''')
WITH (
         MAX_MEMORY = 4096KB
       , EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
       , MAX_DISPATCH_LATENCY = 10 SECONDS
       , MAX_EVENT_SIZE = 0KB
       , MEMORY_PARTITION_MODE = NONE
       , TRACK_CAUSALITY = ON
       , STARTUP_STATE = OFF
     );');

/* PRINT(@sql) */
EXEC master.sys.sp_executesql @sql;
GO


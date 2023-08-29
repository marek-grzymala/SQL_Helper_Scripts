IF EXISTS --if the session already exists, then delete it. We are assuming you've changed something
  (
  SELECT * FROM sys.server_event_sessions
    WHERE server_event_sessions.name = 'CaptureSql_PerDbName_PerText'
  )
  DROP EVENT SESSION [CaptureSql_PerDbName_PerText] ON SERVER;

CREATE EVENT SESSION [CaptureSql_PerDbName_PerText]
ON SERVER
    ADD EVENT sqlserver.sql_statement_completed
    (SET collect_statement = (1)
     ACTION
     (
         sqlserver.client_app_name,
         sqlserver.client_hostname,
         sqlserver.nt_username,
         sqlserver.sql_text,
         sqlserver.username
     )
     WHERE (
               [sqlserver].[is_system] = (0)
               AND [sqlserver].[database_name] = N'DBName'
               AND
               (
                   [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text], N'%Sql Text 1%')
                   OR [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text], N'%Sql Text 2%')
               )
           )
    )
    ADD TARGET package0.event_file
    (SET filename = N'C:\Temp\CaptureSql_PerDbName_PerText.xel')
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = NO_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = OFF
);
GO



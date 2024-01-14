USE [master]
GO

--DROP EVENT SESSION [DeadlockCapture] ON SERVER 

DECLARE @XeName NVARCHAR(256)
	  , @XeFilePath NVARCHAR(2000)
      , @XeFileName NVARCHAR(2000)
	  , @MaxFileSizeMb NVARCHAR(16)
	  , @MaxRolloverFiles NVARCHAR(16)
	  , @EventRetentionMode NVARCHAR(64)
	  , @sql NVARCHAR(MAX);

/* set the variables as desired: */
SET @XeName = N'DeadlockCapture';
SET @XeFilePath = N'C:\MSSQL\Backup\XEL\';
SET @XeFileName = N'DeadlockCapture.xel';
SET @MaxFileSizeMb = '16'; /* the larger the .xel file the longer it takes to import its contents into SQL tables */
SET @MaxRolloverFiles = '5';
SET @EventRetentionMode = 'NO_EVENT_LOSS'; /* if performance impacted change to: ALLOW_SINGLE_EVENT_LOSS or ALLOW_MULTIPLE_EVENT_LOSS */

/* if no @XeFilePath specified place the log file in the same location as your system_health: */
IF (@XeFilePath IS NULL)
BEGIN
	;WITH  cte
	AS
	(
		SELECT		  [s].[name]
					, [t].[target_name]
					, CAST([t].[target_data] AS XML) AS [xml]
		FROM		[sys].[dm_xe_session_targets] AS [t]
		LEFT JOIN	[sys].[dm_xe_sessions] AS [s] ON [s].[address] = [t].[event_session_address]
		WHERE		[s].[name] = 'system_health'
	)
	SELECT		@XeFilePath = SUBSTRING([nodes].[node].value('@name', 'VARCHAR(256)'), 1, LEN([nodes].[node].value('@name', 'VARCHAR(256)')) 
	- CHARINDEX('\', REVERSE([nodes].[node].value('@name', 'varchar(250)'))) + 1)
	FROM		cte
	CROSS APPLY [xml].[nodes]('.//File') [nodes] ([node]);
END


SET @sql = CONCAT('IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE [name] = N''', @XeName, ''')
BEGIN
	DROP EVENT SESSION [', @XeName, '] ON SERVER 
END;', CHAR(13), '
CREATE EVENT SESSION [', @XeName, ']
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
    (SET filename = N''', @XeFilePath, @XeFileName, ''', MAX_FILE_SIZE=(', @MaxFileSizeMb, '), MAX_ROLLOVER_FILES=', @MaxRolloverFiles, ')
	WITH (
         MAX_MEMORY = 4096KB
       , EVENT_RETENTION_MODE = ', @EventRetentionMode, '
       , MAX_DISPATCH_LATENCY = 10 SECONDS
       , MAX_EVENT_SIZE = 0KB
       , MEMORY_PARTITION_MODE = NONE
       , TRACK_CAUSALITY = ON
       , STARTUP_STATE = OFF
     );', CHAR(13),
'ALTER EVENT SESSION [', @XeName, ']
ON SERVER STATE = START;');
EXEC master.sys.sp_executesql @sql;
GO



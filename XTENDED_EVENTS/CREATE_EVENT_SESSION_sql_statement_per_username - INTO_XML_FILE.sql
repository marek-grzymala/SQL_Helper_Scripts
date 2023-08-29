DROP EVENT SESSION [SqlStatementsPerUser] ON SERVER 
GO

CREATE EVENT SESSION [governance_web_UserSessions] ON SERVER 
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.sql_text,sqlserver.tsql_stack)
	WHERE ([sqlserver].[username]='user1')),
ADD EVENT sqlserver.sql_batch_starting(
    ACTION(sqlserver.sql_text,sqlserver.tsql_stack)
	WHERE ([sqlserver].[username]='user2')),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text,sqlserver.tsql_stack)
    WHERE ([sqlserver].[username]='user3')),
ADD EVENT sqlserver.sql_statement_starting(
    ACTION(sqlserver.sql_text,sqlserver.tsql_stack)
	WHERE ([sqlserver].[username]='user4'))
ADD TARGET package0.event_counter,
ADD TARGET package0.event_file(SET filename=N'T:\XTENDED_EVENT_LOGS\SqlStatementsPerUser.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=10 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO



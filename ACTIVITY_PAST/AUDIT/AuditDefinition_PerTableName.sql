USE [master]
GO
CREATE SERVER AUDIT [dbo_NameOfTheTableThatNeedsToBEAudited]
TO FILE
(	FILEPATH = N'F:\PathToYour\Log\Audit\'
	,MAXSIZE = 0 MB
	,MAX_ROLLOVER_FILES = 2147483647
	,RESERVE_DISK_SPACE = OFF
)
WITH
(	QUEUE_DELAY = 10000
	,ON_FAILURE = CONTINUE
)
ALTER SERVER AUDIT [dbo_NameOfTheTableThatNeedsToBEAudited] WITH (STATE = ON)
GO
USE [YourUserDBName]
GO
CREATE DATABASE AUDIT SPECIFICATION [dbo_NameOfTheTableThatNeedsToBEAudited]
FOR SERVER AUDIT [BSL_dbo_NameOfTheTableThatNeedsToBEAudited]
WITH (STATE = OFF)
GO
ALTER DATABASE AUDIT SPECIFICATION [dbo_NameOfTheTableThatNeedsToBEAudited]
ADD (DELETE ON OBJECT::[dbo].[NameOfTheTableThatNeedsToBEAudited] BY [public]),
ADD (INSERT ON OBJECT::[dbo].[NameOfTheTableThatNeedsToBEAudited] BY [public]),
ADD (SELECT ON OBJECT::[dbo].[NameOfTheTableThatNeedsToBEAudited] BY [public]),
ADD (UPDATE ON OBJECT::[dbo].[NameOfTheTableThatNeedsToBEAudited] BY [public])
GO
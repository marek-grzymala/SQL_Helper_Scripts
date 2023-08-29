USE [YourDatabaseName]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BlockedProcess_HeadBlockers_KillHistory](
	[TimeRecorded] [datetime] NULL,
	[SPID] [smallint] NULL,
	[LogiName] [nchar](128) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[ProgramName] [nvarchar](128) NULL,
	[SqlText] [nvarchar](max) NULL,
	[groupName] [nvarchar](100) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE PROCEDURE [dbo].[usp_KillHeadBlockers_Notify]

  @MailRecipients NVARCHAR(256) = N'your_notification@email_address'
, @SPID SMALLINT
, @LogiName NCHAR(128)
, @DatabaseName NVARCHAR(128)
, @ProgramName NVARCHAR(128)
, @SqlText NVARCHAR(MAX)
, @groupName NVARCHAR(100)
AS
BEGIN
DECLARE @TempTable TABLE ([Variable Name] NVARCHAR(256), [Variable Value] NVARCHAR(512))

INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('SPID', @SPID)
INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('Login', @LogiName)
INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('Session Database', @DatabaseName)
INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('Program', @ProgramName)
INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('AD Group', @groupName)
INSERT @TempTable ([Variable Name], [Variable Value]) VALUES ('SQL Text', @SqlText)
----------------------------------------------------------------------------------------------------------------------------------------------
IF (SELECT COUNT(*) FROM @TempTable) > 0
	BEGIN
	DECLARE @HTMLTable VARCHAR(MAX)
	SELECT @HTMLTable = CONVERT
	(
		NVARCHAR(MAX), 
		(SELECT
			(SELECT 'Summary of killed session attributes on: '+ @@SERVERNAME FOR XML PATH(''), TYPE) AS 'caption',
			(SELECT 'Attribute' AS th, 'Value' AS th FOR XML RAW('tr'), ELEMENTS, TYPE) AS 'thead',
			(
				SELECT 
					[Variable Name] AS td,
					[Variable Value] AS td
				FROM @TempTable
			FOR XML RAW('tr'), TYPE, ELEMENTS
			) AS 'tbody'
			FOR XML PATH(''), ROOT('table')
		)
	);
	SET @HTMLTable = replace(replace(@HTMLTable, '&lt;', '<'), '&gt;', '>') -- this is to Replace "&lt;" and "&gt;" with "<" and ">"

----------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @CSS VARCHAR(MAX)
	SELECT @CSS = 
	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	<html>
	<head>
	<style type="text/css">
	table {
	font:12pt tahoma,arial,sans-serif;
	}
	caption {
	color:#FF0000;
	font:bold 12pt tahoma,arial,sans-serif;
	background-color:#FFFF00;
	border:1px solid #DCDCDC;
	border-collapse:collapse;
	padding-left:5px;
	padding-right:5px;
	}
	th {
	color:#FFFFFF;
	font:bold 12pt tahoma,arial,sans-serif;
	background-color:#204c7d;
	border:1px solid #DCDCDC;
	border-collapse:collapse;
	padding-left:5px;
	padding-right:5px;
	}
	td {
	color:#000000;
	font:10pt tahoma,arial,sans-serif;
	border:1px solid #DCDCDC;
	border-collapse:collapse;
	padding-left:3px;
	padding-right:3px;
	}
	.Warning {
	background-color:#FFFF00; 
	color:#2E2E2E;
	}
	.Critical {
	background-color:#FF0000;
	color:#FFFFFF;
	}
	.Healthy {
	background-color:#458B00;
	color:#FFFFFF;
	}
	h1 {
	color:#FFFFFF;
	font:bold 16pt arial,sans-serif;
	background-color:#204c7d;
	text-align:center;
	}
	h2 {
	color:#204c7d;
	font:bold 14pt arial,sans-serif;
	}
	h3 {
	color:#204c7d;
	font:bold 12pt arial,sans-serif;
	}
	body {
	color:#000000;
	font:12pt tahoma,arial,sans-serif;
	margin:0px;
	padding:0px;
	}
	</style>
	</head>'
	DECLARE @MailBody VARCHAR(MAX)
	SET @MailBody = @CSS+@HTMLTable
	--PRINT @MailBody

	DECLARE @MailSubject VARCHAR(250)
	SET @MailSubject = 'Killed Head-Blocker Session notification from '+@@SERVERNAME

	EXECUTE msdb.dbo.sp_send_dbmail
	@profile_name = 'YourEmailProfile',
	@recipients= @MailRecipients,
	@subject = @MailSubject,
	@body = @MailBody,
	@body_format = 'HTML';	
	END
END
GO

CREATE PROCEDURE [dbo].[usp_KillHeadBlockers_Destroy]
--DECLARE
@_SPID SMALLINT, @_LogiName NCHAR(128), @_DatabaseName NVARCHAR(128), @_ProgramName NVARCHAR(128), @_SqlText NVARCHAR(MAX), @_groupName NVARCHAR(100)
--SET @_SPID = 64
AS
BEGIN
	BEGIN TRY

		DECLARE @_sqlCommand NVARCHAR(1000)
		SET @_sqlCommand = 'Kill '+CONVERT(VARCHAR(4), @_SPID);
		EXEC sp_executesql @_sqlCommand
		INSERT INTO dbo.BlockedProcess_HeadBlockers_KillHistory (TimeRecorded, SPID, LogiName, DatabaseName, ProgramName, SqlText, groupName)
		VALUES (GETDATE(), @_SPID, @_LogiName, @_DatabaseName, @_ProgramName, @_SqlText, @_groupName)
		
			EXEC [dbo].[usp_KillHeadBlockers_Notify] 
				@SPID					= @_SPID
				, @LogiName				= @_LogiName
				, @DatabaseName			= @_DatabaseName
				, @ProgramName			= @_ProgramName
				, @SqlText				= @_SqlText
				, @groupName			= @_groupName

	END TRY
	BEGIN CATCH
	    SELECT   
			ERROR_NUMBER()		AS ErrorNumber  
        ,	ERROR_SEVERITY()	AS ErrorSeverity  
        ,	ERROR_STATE()		AS ErrorState  
        ,	ERROR_PROCEDURE()	AS ErrorProcedure  
        ,	ERROR_LINE()		AS ErrorLine  
        ,	ERROR_MESSAGE()		AS ErrorMessage;  
		IF @@TRANCOUNT > 0  ROLLBACK TRANSACTION;  
	END CATCH

END
GO


CREATE PROCEDURE [dbo].[usp_KillHeadBlockers_Seek]
AS
BEGIN

DECLARE @DomainPrefix VARCHAR(64), @ProtectedLogin NCHAR(128)
SET @DomainPrefix = 'AD_DOMAIN_NAME\';
SET @ProtectedLogin = 'Account_you_do_not_want_to_get_killed'

IF OBJECT_ID('Tempdb..#AllProcesses') IS NOT NULL DROP TABLE #AllProcesses
SELECT
				s.spid
				, [BlockingSPID] = s.blocked
				, [DatabaseName] = DB_NAME(s.[dbid])
				, s.[program_name]
				, REPLACE(s.[loginame], @DomainPrefix, '') AS [loginame]
				, ObjectName = OBJECT_NAME(objectid, s.[dbid])
				, SqlText = CAST(t.[text] AS VARCHAR(MAX))

INTO			#AllProcesses
FROM			sys.sysprocesses s
CROSS APPLY		sys.dm_exec_sql_text (sql_handle) t
WHERE			s.spid > 50

IF OBJECT_ID('Tempdb..#SpidsToBeKilled') IS NOT NULL DROP TABLE #SpidsToBeKilled
CREATE TABLE #SpidsToBeKilled (SPID SMALLINT, LogiName NCHAR(128), DatabaseName NVARCHAR(128), ProgramName NVARCHAR(128), SqlText NVARCHAR(MAX), groupName NVARCHAR(100))


; WITH AllBlocking (SPID, LogiName, BlockingSPID, ChainNum, BlockingLevel, DatabaseName, ProgramName, SqlText)
AS

(
    SELECT
      s.SPID
	  , s.[LogiName]
	  , s.[BlockingSPID]
      , ROW_NUMBER() OVER(ORDER BY s.[SPID]) AS [ChainNum]
      , 0 AS [BlockingLevel]
	  , s.[DatabaseName]
	  , s.[program_name]
	  , s.[SqlText]
    FROM
      #AllProcesses s JOIN #AllProcesses s1 ON s.SPID = s1.[BlockingSPID]
    WHERE
      s.[BlockingSPID] = 0

    UNION ALL

    SELECT
      r.SPID
	  , r.[LogiName]
	  , r.[BlockingSPID]
	  , b.[ChainNum]
      , b.[BlockingLevel] + 1
	  , r.[DatabaseName]
	  , r.[program_name]
	  , r.[SqlText]
    FROM
      #AllProcesses r JOIN AllBlocking b ON r.[BlockingSPID] = b.SPID
    WHERE
      r.[BlockingSPID] > 0
)

INSERT INTO #SpidsToBeKilled ([SPID], [LogiName], [DatabaseName], [ProgramName], [SqlText], [groupName])
SELECT DISTINCT
					  b1.[SPID]
					, b1.[LogiName]
					, b1.[DatabaseName]
					, b1.[ProgramName]
					, b1.[SqlText]
					, sag.[groupName]
FROM 
		sox.GroupsUsers					sgu
		LEFT JOIN sox.ADGroup			sag ON sag.ID			= sgu.groupID
		LEFT JOIN sox.ADUser			sau ON sau.ID			= sgu.userID
		INNER JOIN AllBlocking			b1	ON b1.[LogiName]	= sau.accountName
		INNER JOIN AllBlocking			b2	ON b1.ChainNum		= b2.ChainNum
WHERE

		-- select head-blockers only:	
		b1.[BlockingLevel] = 0
		-- ignore head-blockers from the @ProtectedLogin
		AND	b1.[LogiName] <> @ProtectedLogin
		-- select only the blocking chains that have @ProtectedLogin as one of the blocked SPIDs (we care only about this account getting blocked):
		AND	b2.[LogiName] = @ProtectedLogin
		-- select head-blockers that belong to an active AD Group:
		AND sgu.isActive = 'Y'
		-- select head-blockers that are members of only these AD Groups:
		AND sag.groupName IN ('AD_offending_group1', 'AD_offending_group2', 'AD_offending_group3')

--SELECT * FROM #SpidsToBeKilled

DECLARE SpidsToBeKilled_Cursor CURSOR FOR SELECT [SPID], [LogiName], [DatabaseName], [ProgramName], [SqlText], [groupName] FROM #SpidsToBeKilled
DECLARE @SPID SMALLINT, @LogiName NCHAR(128), @DatabaseName NVARCHAR(128), @ProgramName NVARCHAR(128), @SqlText NVARCHAR(MAX), @groupName NVARCHAR(100)


	OPEN SpidsToBeKilled_Cursor
	FETCH NEXT FROM SpidsToBeKilled_Cursor INTO @SPID, @LogiName, @DatabaseName, @ProgramName, @SqlText, @groupName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--SELECT @SPID, @LogiName, @DatabaseName, @ProgramName, @SqlText, @groupName
		EXEC [dbo].[usp_KillHeadBlockers_Destroy] @_SPID = @SPID, @_LogiName = @LogiName, @_DatabaseName = @DatabaseName, @_ProgramName = @ProgramName, @_SqlText = @SqlText, @_groupName = @groupName
		FETCH NEXT FROM SpidsToBeKilled_Cursor INTO @SPID, @LogiName, @DatabaseName, @ProgramName, @SqlText, @groupName
	END
	CLOSE SpidsToBeKilled_Cursor  
	DEALLOCATE SpidsToBeKilled_Cursor

END
GO





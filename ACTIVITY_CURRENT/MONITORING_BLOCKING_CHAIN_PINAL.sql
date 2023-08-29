SET NOCOUNT ON
GO
SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T
GO
WITH [BLOCKERS] (SPID, BLOCKED, LEVEL, BATCH)
AS
	(
		SELECT 
			SPID,
			BLOCKED,
			CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
			BATCH 
		FROM #T R
		WHERE (BLOCKED = 0 OR BLOCKED = SPID) AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
		UNION ALL
		SELECT 
			R.SPID,
			R.BLOCKED,
			CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
			R.BATCH 
		FROM #T AS R
		INNER JOIN [BLOCKERS] ON R.BLOCKED = BLOCKERS.SPID 
		WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID
	)
SELECT 
	N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
	CASE WHEN (LEN(LEVEL)/4 - 1) = 0
	THEN 'HEAD -  '
	ELSE '|------  ' END
	+ CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS [BLOCKING_TREE]
FROM [BLOCKERS] ORDER BY LEVEL ASC
GO
DROP TABLE #T
GO

USE DBAAdmin
GO


DECLARE @schema VARCHAR(MAX);
EXEC dbo.sp_WhoIsActive

 @find_block_leaders = 1
,@sort_order = '[blocked_session_count] DESC'
,@show_sleeping_spids = 1
,@get_plans = 1
,@get_outer_command = 2
,@get_transaction_info = 2 -- bit
,@get_additional_info = 2 

,@filter_type = 'login'
,@filter = 'DOMAIN\username'

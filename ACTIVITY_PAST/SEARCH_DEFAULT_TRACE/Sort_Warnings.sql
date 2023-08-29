-- based on: https://www.mssqltips.com/sqlservertip/3445/using-the-sql-server-default-trace-to-audit-events/

DECLARE @NewestTraceFilePath NVARCHAR(1000), @TraceDirPath NVARCHAR(1000), @OldestTraceFilePath NVARCHAR(1000)

SET @NewestTraceFilePath = (SELECT [path] FROM sys.traces WHERE is_default = 1)
SELECT @TraceDirPath = SUBSTRING(@NewestTraceFilePath, 1, LEN(@NewestTraceFilePath) - CHARINDEX('\', reverse(@NewestTraceFilePath)))
DECLARE @cmd NVARCHAR(256) = 'DIR '+@TraceDirPath+'\*.trc /TA'
PRINT '@cmd: '+@cmd

IF OBJECT_ID('tempdb..#cmdShellResults') IS NOT NULL
      DROP TABLE #cmdShellResults;
CREATE TABLE #cmdShellResults
		(
			[row] NVARCHAR(400)
		)
INSERT	#cmdShellResults
		(
			[row]
		)
EXEC master..xp_cmdshell @cmd
--SELECT * FROM #cmdShellResults

; WITH FileListing AS
(
SELECT [FileName] = SUBSTRING([row], 37, 400) FROM #cmdShellResults WHERE SUBSTRING([row], 37, 400) LIKE '%.trc'
) 
SELECT @OldestTraceFilePath = @TraceDirPath+'\'+(SELECT TOP 1 [FileName] FROM FileListing)


--Security Audit: Audit Backup/Restore Event
SELECT 
				  tt.DatabaseName
				, tt.FileName
				, tt.ObjectID
				, tt.ObjectType
				, tt.ObjectName
				, tt.TextData
				, tt.Duration
				, tt.StartTime
				, tt.EndTime
				, tt.SPID
				, tt.ApplicationName
				, tt.LoginName
				, te.name
FROM 
				sys.fn_trace_gettable(@OldestTraceFilePath, DEFAULT) AS tt
--				sys.fn_trace_gettable(@NewestTraceFilePath, DEFAULT) AS tt -- <= for comparison if we search only the newest trace file
INNER JOIN		sys.trace_events te on tt.eventclass = te.trace_event_id	
WHERE			
--				tt.EventClass IN (22) and tt.EventSubClass = 1
-- to see all Events: SELECT * FROM sys.trace_events
				te.name IN ('Sort Warnings')
ORDER BY		tt.StartTime DESC


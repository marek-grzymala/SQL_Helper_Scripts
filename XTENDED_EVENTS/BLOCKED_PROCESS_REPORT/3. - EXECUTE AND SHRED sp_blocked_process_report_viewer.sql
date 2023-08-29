USE TempDB
GO


--DROP TABLE #bpr
CREATE TABLE #bpr (
    EndTime DATETIME,
	DatabaseName NVARCHAR(MAX),
	Duration BIGINT,
    TextData XML,
    EventClass INT DEFAULT(137)
);
GO

TRUNCATE TABLE #bpr

WITH events_cte AS (
    SELECT
        DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), CURRENT_TIMESTAMP),
        xevents.event_data.value('(event/@timestamp)[1]','datetime2')) AS [event_time],
		xevents.event_data.value('(event[@name="blocked_process_report"]/data[@name="database_name"]/value)[1]', 'nvarchar(max)') AS [database name],
		xevents.event_data.value('(event[@name="blocked_process_report"]/data[@name="lock_mode"]/text)[1]', 'varchar') AS [lock_mode],
		xevents.event_data.value('(event[@name="blocked_process_report"]/data[@name="duration"]/value)[1]', 'bigint') / 1000 AS [duration (ms)],
		xevents.event_data.value('(event[@name="blocked_process_report"]/data[@name="clientapp"]/value)[1]', 'nvarchar(max)') AS [clientapp],
        xevents.event_data.query('(event[@name="blocked_process_report"]/data[@name="blocked_process"]/value/blocked-process-report)[1]') AS [blocked_process_report]
    FROM    
		sys.fn_xe_file_target_read_file('U:\XTENDED EVENTS LOGS\blocked_process*.xel',null, null, null)
		CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) as xevents
	--ORDER BY [event_time] DESC
)
INSERT INTO #bpr (EndTime, TextData)
SELECT
    [event_time],
    [blocked_process_report]
FROM events_cte
WHERE blocked_process_report.value('(blocked-process-report[@monitorLoop])[1]', 'nvarchar(max)') IS NOT NULL
ORDER BY [event_time] DESC

/*
-- traceTime in UTC:
exec TempDb.dbo.sp_blocked_process_report_viewer
    @Source = 'blocked_process', -- the name that Jeremiah gave to his xe session
    @Type = 'XESESSION';
*/

--DROP TABLE #sp_blocked_process_report
CREATE TABLE #sp_blocked_process_report
(
	traceTime nvarchar(100) NOT NULL,
	blockingTree nvarchar(100) NOT NULL,
	bpReportXml XML NULL
)

TRUNCATE TABLE #sp_blocked_process_report

INSERT INTO #sp_blocked_process_report
(
	traceTime,
	blockingTree,
	bpReportXml
)
EXEC TempDb.dbo.sp_blocked_process_report_viewer @Type='TABLE', @Source='#bpr';

--shred the #sp_blocked_process_report table:

SELECT --DISTINCT(TempDb.dbo.RoundTime(traceTime, 0.01666)) AS [DISTINCT BLOCKING DATE TIME] 

	  traceTime
	, blockingTree
	, bpShredded.blocked_spid
	, DB_NAME(bpShredded.blocked_currentdb) AS blocked_currentdb
	, bpShredded.blocked_clientapp
	, bpShredded.blocked_hostname
	, bpShredded.blocked_waittime
	, bpShredded.blocked_loginname
	, bpShredded.blocked_inputbuf
	
	, bpShredded.blocking_spid
	, DB_NAME(bpShredded.blocking_currentdb) AS blocking_currentdb
	, bpShredded.blocking_clientapp
	, bpShredded.blocking_hostname
	, bpShredded.blocking_loginname
	, bpShredded.blocking_inputbuf
FROM 
	#sp_blocked_process_report
			CROSS APPLY (
			SELECT 
				monitorloop = bpReportXml.value('(//@monitorLoop)[1]', 'nvarchar(100)'),
				blocked_spid = bpReportXml.value('(/blocked-process-report/blocked-process/process/@spid)[1]', 'int'),
				blocked_ecid = bpReportXml.value('(/blocked-process-report/blocked-process/process/@ecid)[1]', 'int'),
				blocked_currentdb = bpReportXml.value('(/blocked-process-report/blocked-process/process/@currentdb)[1]', 'int'),
				blocked_waittime = bpReportXml.value('(/blocked-process-report/blocked-process/process/@waittime)[1]', 'bigint'),
				blocked_clientapp = bpReportXml.value('(/blocked-process-report/blocked-process/process/@clientapp)[1]', 'nvarchar(max)'),
				blocked_hostname = bpReportXml.value('(/blocked-process-report/blocked-process/process/@hostname)[1]', 'nvarchar(max)'),
				blocked_loginname = bpReportXml.value('(/blocked-process-report/blocked-process/process/@loginname)[1]', 'nvarchar(max)'),
				blocked_inputbuf = bpReportXml.value('(/blocked-process-report/blocked-process/process/inputbuf)[1]', 'nvarchar(max)'),
				
				blocking_spid = bpReportXml.value('(/blocked-process-report/blocking-process/process/@spid)[1]', 'int'),
				blocking_currentdb = bpReportXml.value('(/blocked-process-report/blocking-process/process/@currentdb)[1]', 'int'),
				blocking_clientapp = bpReportXml.value('(/blocked-process-report/blocking-process/process/@clientapp)[1]', 'nvarchar(max)'),
				blocking_hostname = bpReportXml.value('(/blocked-process-report/blocking-process/process/@hostname)[1]', 'nvarchar(max)'),
				blocking_loginname = bpReportXml.value('(/blocked-process-report/blocking-process/process/@loginname)[1]', 'nvarchar(max)'),
				blocking_inputbuf = bpReportXml.value('(/blocked-process-report/blocking-process/process/inputbuf)[1]', 'nvarchar(max)')
			) AS bpShredded
WHERE traceTime NOT IN ('Lead')
ORDER BY traceTime
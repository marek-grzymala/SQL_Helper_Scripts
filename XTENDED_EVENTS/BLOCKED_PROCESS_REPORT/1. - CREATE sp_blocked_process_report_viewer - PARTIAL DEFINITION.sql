IF OBJECT_ID('TempDb..#ReportsXML') IS NOT NULL 
BEGIN 
	DROP TABLE #ReportsXML
	PRINT 'Table #ReportsXML dropped'
END
	CREATE TABLE #ReportsXML
	(
       [monitorloop] nvarchar(100) NOT NULL,
       [endTime] datetime NULL,
       [blocking_spid] INT NOT NULL,
	   [blocking_ecid] INT NOT NULL,       
	   [blocking_TransactionStarted] DATETIME, 
	   [blocking_Login] NVARCHAR(256),
	   [blocking_HostName] NVARCHAR(256), 
	   [blocking_ClientApp] NVARCHAR(256), 
	   [blocking_DBID] INT,  
       [blocking_bfinput] NVARCHAR(MAX),	   


       [blocked_spid] INT NOT NULL,
       [blocked_ecid] INT NOT NULL,
	   [blocked_TransactionStarted] DATETIME,
	   [blocked_Login] NVARCHAR(256),
	   [blocked_HostName] NVARCHAR(256),
	   [blocked_ClientApp] NVARCHAR(256),
       [blocked_bfinput] NVARCHAR(MAX),

       [blocked_waitime] BIGINT,
       [blocked_hierarchy_string] as CAST(blocked_spid as varchar(20)) + '.' + CAST(blocked_ecid as varchar(20)) + '/',
       [blocking_hierarchy_string] as CAST(blocking_spid as varchar(20)) + '.' + CAST(blocking_ecid as varchar(20)) + '/',
       [bpReportXml] xml NOT NULL,
       PRIMARY KEY CLUSTERED (monitorloop, blocked_spid, blocked_ecid),
       UNIQUE NONCLUSTERED (monitorloop, blocking_spid, blocking_ecid, blocked_spid, blocked_ecid)
	)

DECLARE @FilenamePattern nvarchar(max),	@Source nvarchar(max),	@Type varchar(10) = 'XESESSION' 
SET @Source = 'blocked_process'
DECLARE @SessionType nvarchar(max);
DECLARE @SessionId int;
DECLARE @SessionTargetId int;

	SELECT TOP ( 1 ) 
		@SessionType = est.name,
		@SessionId = est.event_session_id,
		@SessionTargetId = est.target_id
	FROM sys.server_event_sessions es
	JOIN sys.server_event_session_targets est
		ON es.event_session_id = est.event_session_id
	WHERE est.name in ('event_file', 'ring_buffer')
		AND es.name = @Source;
	IF (@SessionType = 'event_file')
	BEGIN
		 
		SELECT @filenamePattern = REPLACE( CAST([value] AS nvarchar(max)), '.xel', '*xel' )
		FROM sys.server_event_session_fields
		WHERE event_session_id = @SessionId
		  AND [object_id] = @SessionTargetId
		  AND name = 'filename'

		IF (@filenamePattern not like '%xel')
			set @filenamePattern += '*xel'

		INSERT #ReportsXML(
							  [monitorloop]
							, [endTime]
							, [blocking_spid]
							, [blocking_ecid]
							, [blocking_TransactionStarted]
							, [blocking_Login]
							, [blocking_HostName]
							, [blocking_ClientApp]
							, [blocking_DBID]
							, [blocking_bfinput]
							
							, [blocked_spid]
							, [blocked_ecid]
							, [blocked_TransactionStarted]
							, [blocked_Login]
							, [blocked_HostName]
							, [blocked_ClientApp]
							, [blocked_bfinput]
							, [bpReportXml]

						   )
		
		SELECT 
							COALESCE(monitorloop, CONVERT(nvarchar(100), eventDate, 120), cast(newid() as nvarchar(100)))
							, eventDate
							, blocking_spid
							, blocking_ecid
							, CAST (bpReportXml.value('(blocked-process-report/blocking-process/process/@lastbatchstarted)[1]','datetime') AS DATETIME)
							, bpReportXml.value('(blocked-process-report/blocking-process/process/@loginname)[1]','sysname')
							, bpReportXml.value('(blocked-process-report/blocking-process/process/@hostname)[1]','sysname')
							, bpReportXml.value('(blocked-process-report/blocking-process/process/@clientapp)[1]','nvarchar(max)')
							, CAST (bpReportXml.value('(blocked-process-report/blocking-process/process/@currentdb)[1]','int') AS INT)
							, bpReportXml.value('(blocked-process-report/blocking-process/process/inputbuf)[1]','nvarchar(max)')
							
							, blocked_spid
							, blocked_ecid
							, CONVERT (DATETIME, bpReportXml.value('(blocked-process-report/blocked-process/process/@lasttranstarted)[1]','datetime'))
							, bpReportXml.value('(blocked-process-report/blocked-process/process/@loginname)[1]','sysname')
							, bpReportXml.value('(blocked-process-report/blocked-process/process/@hostname)[1]','sysname')
							, bpReportXml.value('(blocked-process-report/blocked-process/process/@clientapp)[1]','nvarchar(max)')
							, bpReportXml.value('(blocked-process-report/blocked-process/process/inputbuf)[1]','nvarchar(max)')
							, bpReportXml

		FROM sys.fn_xe_file_target_read_file ( @filenamePattern, null, null, null) 
			as event_file_value
		
		CROSS APPLY ( SELECT CAST(event_file_value.[event_data] as xml) ) 
			as event_file_value_xml ([xml])
		
		CROSS APPLY (
			SELECT 
				event_file_value_xml.[xml].value('(event/@timestamp)[1]', 'datetime') as eventDate,
				event_file_value_xml.[xml].query('//event/data/value/blocked-process-report') as bpReportXml	
		) as bpReports
		CROSS APPLY (
			SELECT 
				monitorloop = bpReportXml.value('(//@monitorLoop)[1]', 'nvarchar(100)'),
				blocked_spid = bpReportXml.value('(/blocked-process-report/blocked-process/process/@spid)[1]', 'int'),
				blocked_ecid = bpReportXml.value('(/blocked-process-report/blocked-process/process/@ecid)[1]', 'int'),
				blocking_spid = bpReportXml.value('(/blocked-process-report/blocking-process/process/@spid)[1]', 'int'),
				blocking_ecid = bpReportXml.value('(/blocked-process-report/blocking-process/process/@ecid)[1]', 'int')
			) AS bpShredded
		
		WHERE blocking_spid is not null
		  AND blocked_spid is not null;

	END

SELECT * FROM #ReportsXML ORDER BY monitorloop
--------------------------


-- Organize and select blocked process reports
;WITH Blockheads AS
(
       SELECT [blocking_spid], [blocking_ecid], [monitorloop], [blocking_hierarchy_string], [blocking_Login], [blocking_HostName], [blocking_ClientApp]
       FROM #ReportsXML
       EXCEPT
       SELECT [blocked_spid], [blocked_ecid], [monitorloop], [blocked_hierarchy_string], [blocked_Login], [blocked_HostName], [blocked_ClientApp]
       FROM #ReportsXML
),
Hierarchy AS
(

       SELECT monitorloop, blocking_spid AS spid, blocking_ecid AS ecid,
             cast('/' + blocking_hierarchy_string AS VARCHAR(MAX)) as chain,
             0 as level,
			 ISNULL (bh.[blocking_Login], '') AS [blocking_Login],
			 ISNULL (bh.[blocking_HostName], '') AS [blocking_HostName],
			 ISNULL (bh.[blocking_ClientApp], '') AS [blocking_ClientApp]
       FROM Blockheads bh
     
       UNION ALL
    
       SELECT irx.monitorloop, irx.blocked_spid, irx.blocked_ecid,
             cast(h.chain + irx.blocked_hierarchy_string AS VARCHAR(MAX)),
             h.level+1,
			 ISNULL(irx.[blocked_Login], '') AS [blocked_Login],
			 ISNULL (irx.[blocked_HostName], '') AS [blocked_HostName],
			 ISNULL (irx.[blocked_ClientApp], '') AS [blocked_ClientApp]


       FROM #ReportsXML irx
       JOIN Hierarchy h
             ON irx.monitorloop = h.monitorloop
             AND irx.blocking_spid = h.spid
             AND irx.blocking_ecid = h.ecid
)

SELECT
			ISNULL(CONVERT(NVARCHAR(30), r.endTime, 120),'Lead')		AS [traceTime],
			SPACE(4 * h.[level])
			      + CAST(h.[spid] as varchar(20))
			      + CASE h.[ecid]
			             WHEN 0 THEN ''
			             ELSE '(' + CAST(h.ecid AS VARCHAR(20)) + ')'
			      END													AS [blockingTree],
			CASE 
				WHEN h.blocking_Login = r.blocked_Login THEN '-'
				ELSE h.blocking_Login
			END															AS [blocking_Login],
			
			CASE 
				WHEN h.blocking_HostName = r.blocked_HostName THEN '-'
				ELSE h.blocking_HostName
			END															AS [blocking_HostName],
			CASE 
				WHEN h.blocking_ClientApp = r.blocked_ClientApp THEN '-'
				ELSE h.blocking_ClientApp
			END															AS [blocking_ClientApp],	

			ISNULL(r.blocked_Login, '')									AS [blocked_Login],
			ISNULL(r.blocked_HostName, '')								AS [blocked_HostName],
			ISNULL(r.blocked_ClientApp, '')								AS [blocked_ClientApp]


FROM		Hierarchy h
LEFT JOIN	#ReportsXML r on r.monitorloop = h.monitorloop
AND			r.blocked_spid = h.spid
AND			r.blocked_ecid = h.ecid

ORDER BY h.monitorloop, h.chain


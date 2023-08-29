/* https://blog.waynesheffield.com/wayne/code-library/deadlocks/shred-deadlock-graph/ */
-- REFERENCES:
-- see //msdn.microsoft.com/en-us/library/ms188246.aspx
-- (MS BOL Analyzing Deadlocks with SQL Server Profiler)
-- see //msdn.microsoft.com/en-us/library/ms175519.aspx
-- (MS BOL Lock Modes)
-- //blogs.msdn.com/bartd/archive/2006/09/09/Deadlock-Troubleshooting_2C00_-Part-1.aspx
-- //blogs.msdn.com/b/bartd/archive/2008/09/24/today-s-annoyingly-unwieldy-term-intra-query-parallel-thread-deadlocks.aspx
-- Shred XML Deadlock Graphs, showing in tabular format as much information as possible.
-- Insert the XML Deadlock Graph into the @xml_report table.
-- Author: Wayne Sheffield
-- Modification History:
-- Version - Date       - Description
-- 2         2010-10-10 - Added individual items in the Execution Stack node.
--                      - Converted from using an XML variable to a table variable with an XML variable
--                      -   to allow seeing multiple deadlocks simultaneously.
-- 3         2010-10-11 - Added KPID to Process CTE and final results.
--                      - Expanded LockMode to varchar(10).
-- 4         2011-05-11 - Added Waits.
-- 5         2011-05-15 - Revamped to minimize calls to the root of the deadlock xml nodes.
--                        Modified InputBuffer to be XML.
--                        Modified Execution Stack to return XML (vs. one row for each item, which
--                          was causing duplication of other data).
-- 6         2012-02-01 - Add loading deadlock info from fn_trace_gettable.
--                      - Get the InputBuffer from .query vs. trying to build XML.
--                      - Add number of processes involved in the deadlock.
--                      - Add the Query Statement being run.
-- 7         2012-09-01 - Corrected typo in ObjNode in both the Locks and Waits CTEs.
--                      - Added DENSE_RANK for each process.
--                      - Added support for exchangeEvent, threadpool, resourceWait events.
--                      -   (threadpool and resourceWait events are not tested - need to find a deadlock with them to test)
--                      - Simplified xpath queries
-- 8         2012-09-04 - Greatly simplified locks and waits CTEs based on feedback from Mark Cowne.
--                      - Added database_id and AssociatedObjectId per feedback from Gianluca Sartori.
--                      - Combined the Locks and Waits CTEs into one.
-- 9         2012-10-26 - Handle deadlock graphs from the system_health xe (has a victim-list node for multi-victim deadlocks).
-- 10        2013-07-29 - Added ability to load in a deadlock file (.xdl).
--                      - Added QueryStatement to output.
--                      - Switched from clause order from "Locks JOIN Process" to "Process LEFT JOIN Locks"
-- 11        2013-12-26 - Read in deadlocks from the system_health XE file target
-- 12        2014-05-06 - Read in deadlocks from the system_health XE ring buffer
-- 13        2014-07-01 - Read in deadlocks from SQL Sentry

DECLARE @xml_report TABLE (
        DeadlockID INT IDENTITY PRIMARY KEY CLUSTERED,
        DeadlockGraph XML
        );
-- use below to load a deadlock trace file
/*
DECLARE @file VARCHAR(500);
SELECT  @file = REVERSE(SUBSTRING(REVERSE([PATH]), CHARINDEX('\', REVERSE([path])), 260)) + N'LOG.trc'
FROM    sys.traces 
WHERE   is_default = 1; -- get the system default trace, use different # for other active traces.

-- or just SET @file = 'your trace file to load';

INSERT  INTO @xml_report (DeadlockGraph)
SELECT  TextData
FROM    ::FN_TRACE_GETTABLE(@file, DEFAULT)
WHERE   TextData LIKE '%';
*/

-- or read in a deadlock file - doesn't have to have a "xdl" extension.
/*
INSERT INTO @xml_report (DeadlockGraph)
SELECT *
FROM OPENROWSET(BULK 'Deadlock.xdl', SINGLE_BLOB) UselessAlias;
*/


-- or read in the deadlock from the system_health XE file target
/*
WITH cte1 AS
(
SELECT	target_data = convert(XML, target_data)
FROM	sys.dm_xe_session_targets t
		JOIN sys.dm_xe_sessions s 
		  ON t.event_session_address = s.address
WHERE	t.target_name = 'event_file'
AND		s.name = 'system_health'
), cte2 AS
(
SELECT	[FileName] = FileEvent.FileTarget.value('@name', 'varchar(1000)')
FROM	cte1
		CROSS APPLY cte1.target_data.nodes('//EventFileTarget/File') FileEvent(FileTarget)
), cte3 AS
(
SELECT	event_data = CONVERT(XML, t2.event_data)
FROM    cte2
		CROSS APPLY sys.fn_xe_file_target_read_file(cte2.[FileName], NULL, NULL, NULL) t2
WHERE	t2.object_name = 'xml_deadlock_report'
)
INSERT INTO @xml_report(DeadlockGraph)
SELECT  Deadlock = Deadlock.Report.query('.')
FROM	cte3	
		CROSS APPLY cte3.event_data.nodes('//event/data/value/deadlock') Deadlock(Report);
*/

-- or read in the deadlock from the system_health XE ring buffer
/*
INSERT INTO @xml_report(DeadlockGraph)
SELECT  --XEventData.XEvent.value('@timestamp', 'datetime') AS DeadlockDateTime,
        CONVERT(XML, XEventData.XEvent.value('(data/value)[1]', 'varchar(max)')) AS DeadlockGraph
FROM    (SELECT CAST(target_data AS XML) AS TargetData
         FROM   sys.dm_xe_session_targets st WITH (NOLOCK)
                JOIN sys.dm_xe_sessions s WITH (NOLOCK)
                  ON s.address = st.event_session_address
         WHERE  name = 'system_health'
        ) AS Data
        CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData (XEvent)
WHERE   XEventData.XEvent.value('@name', 'varchar(4000)') = 'xml_deadlock_report';
*/

/*
-- or read in the deadlock from SQL Sentry deadlock collection
INSERT INTO @xml_report(DeadlockGraph)
SELECT  deadlockxml
FROM    dbo.PerformanceAnalysisTraceDeadlock
*/

-- use below to load individual deadlocks.
INSERT INTO @xml_report VALUES ('<deadlock>
  <victim-list>
    <victimProcess id="processf8ad948ca8" />
  </victim-list>
  <process-list>
    <process id="processf8ad948ca8" taskpriority="0" logused="0" waitresource="KEY: 21:72057594043301888 (e53d5c355917)" ownerId="35147106512" transactionname="user_transaction" lasttranstarted="2019-11-14T08:40:22.530" XDES="0x36d4d93900" lockMode="S" schedulerid="19" kpid="30648" status="suspended" spid="203" sbid="0" ecid="0" priority="0" trancount="1" lastbatchstarted="2019-11-14T08:40:22.530" lastbatchcompleted="2019-11-14T08:40:22.530" lastattention="1900-01-01T00:00:00.530" clientapp="Report Server" hostname="SC1WNPRNDB004" hostpid="9968" loginname="WHGROUP\svcPBIRSServices" isolationlevel="read committed (2)" xactid="35147106512" currentdb="20" currentdbname="ReportServer" lockTimeout="4294967295" clientoption1="671088672" clientoption2="128056">
      <executionStack>
        <frame procname="ReportServer.dbo.GetSessionData" line="97" stmtstart="5392" stmtend="8216" sqlhandle="0x03001400a12c5a16f349b9002caa000001000000000000000000000000000000000000000000000000000000">
SELECT
    SN.SnapshotDataID,
    SE.ShowHideInfo,
    SE.DataSourceInfo,
    SN.Description,
    SE.EffectiveParams,
    SN.CreatedDate,
    SE.IsPermanentSnapshot,
    SE.CreationTime,
    SE.HasInteractivity,
    SE.Timeout,
    SE.SnapshotExpirationDate,
    SE.ReportPath,
    SE.HistoryDate,
    SE.CompiledDefinition,
    SN.PageCount,
    SN.HasDocMap,
    SE.Expiration,
    SN.EffectiveParams,
    SE.PageHeight,
    SE.PageWidth,
    SE.TopMargin,
    SE.BottomMargin,
    SE.LeftMargin,
    SE.RightMargin,
    SE.AutoRefreshSeconds,
    SE.AwaitingFirstExecution,
    SN.[DependsOnUser],
    SN.PaginationMode,
    SN.ProcessingFlags,
    COMP.ProcessingFlags,



    CASE SE.AwaitingFirstExecution WHEN 1 THEN CONVERT(BIT, 0) ELSE SN.IsCached END,
    SE.SitePath,    </frame>
      </executionStack>
      <inputbuf>
Proc [Database Id = 20 Object Id = 375008417]   </inputbuf>
    </process>
    <process id="process701f434d468" taskpriority="0" logused="0" waitresource="KEY: 21:72057594040745984 (ba48712f0f9c)" waittime="16" ownerId="35147106466" transactionname="user_transaction" lasttranstarted="2019-11-14T08:40:22.517" XDES="0x59f8676f900" lockMode="S" schedulerid="38" kpid="30556" status="suspended" spid="185" sbid="0" ecid="0" priority="0" trancount="2" lastbatchstarted="2019-11-14T08:40:22.517" lastbatchcompleted="2019-11-14T08:40:22.517" lastattention="1900-01-01T00:00:00.517" clientapp="Report Server" hostname="SC1WNPRNDB004" hostpid="9968" loginname="WHGROUP\svcPBIRSServices" isolationlevel="read committed (2)" xactid="35147106466" currentdb="20" currentdbname="ReportServer" lockTimeout="4294967295" clientoption1="671088672" clientoption2="128056">
      <executionStack>
        <frame procname="ReportServer.dbo.DereferenceSessionSnapshot" line="15" stmtstart="744" stmtend="1294" sqlhandle="0x03001400bd9b8912d149b9002caa000001000000000000000000000000000000000000000000000000000000">
UPDATE SN
SET TransientRefcount = TransientRefcount - 1
FROM
   [ReportServerTempDB].dbo.SnapshotData AS SN
   INNER JOIN [ReportServerTempDB].dbo.SessionData AS SE ON SN.SnapshotDataID = SE.SnapshotDataID
WHERE
   SE.SessionID = @SessionID AND
   SE.OwnerID = @OwnerI    </frame>
        <frame procname="ReportServer.dbo.ClearSessionSnapshot" line="12" stmtstart="588" stmtend="690" sqlhandle="0x03001400f705131c1a4ab9002caa000001000000000000000000000000000000000000000000000000000000">
EXEC DereferenceSessionSnapshot @SessionID, @OwnerI    </frame>
      </executionStack>
      <inputbuf>
Proc [Database Id = 20 Object Id = 471008759]   </inputbuf>
    </process>
    <process id="process6bcd088eca8" taskpriority="0" logused="668" waitresource="KEY: 21:72057594040745984 (ba48712f0f9c)" waittime="11" ownerId="35147106095" transactionname="user_transaction" lasttranstarted="2019-11-14T08:40:22.477" XDES="0x55d33c74040" lockMode="U" schedulerid="32" kpid="26172" status="suspended" spid="102" sbid="0" ecid="0" priority="0" trancount="2" lastbatchstarted="2019-11-14T08:40:22.480" lastbatchcompleted="2019-11-14T08:40:22.480" lastattention="1900-01-01T00:00:00.480" clientapp="Report Server" hostname="SC1WNPRNDB004" hostpid="9968" loginname="WHGROUP\svcPBIRSServices" isolationlevel="read committed (2)" xactid="35147106095" currentdb="20" currentdbname="ReportServer" lockTimeout="4294967295" clientoption1="671088672" clientoption2="128056">
      <executionStack>
        <frame procname="ReportServer.dbo.ClearSessionSnapshot" line="14" stmtstart="700" stmtend="1424" sqlhandle="0x03001400f705131c1a4ab9002caa000001000000000000000000000000000000000000000000000000000000">
UPDATE SE
SET
   SE.SnapshotDataID = null,
   SE.IsPermanentSnapshot = null,
   SE.SnapshotExpirationDate = null,
   SE.ShowHideInfo = null,
   SE.HasInteractivity = null,
   SE.AutoRefreshSeconds = null,
   SE.Expiration = @Expiration
FROM
   [ReportServerTempDB].dbo.SessionData AS SE
WHERE
   SE.SessionID = @SessionID AND
   SE.OwnerID = @OwnerI    </frame>
      </executionStack>
      <inputbuf>
Proc [Database Id = 20 Object Id = 471008759]   </inputbuf>
    </process>
  </process-list>
  <resource-list>
    <keylock hobtid="72057594043301888" dbid="21" objectname="ReportServerTempDB.dbo.SnapshotData" indexname="IX_SnapshotData" id="lockabf20d6fa80" mode="X" associatedObjectId="72057594043301888">
      <owner-list>
        <owner id="process6bcd088eca8" mode="X" />
      </owner-list>
      <waiter-list>
        <waiter id="processf8ad948ca8" mode="S" requestType="wait" />
      </waiter-list>
    </keylock>
    <keylock hobtid="72057594040745984" dbid="21" objectname="ReportServerTempDB.dbo.SessionData" indexname="IDX_SessionData" id="lock45662aca500" mode="X" associatedObjectId="72057594040745984">
      <owner-list>
        <owner id="processf8ad948ca8" mode="X" />
      </owner-list>
      <waiter-list>
        <waiter id="process701f434d468" mode="S" requestType="wait" />
      </waiter-list>
    </keylock>
    <keylock hobtid="72057594040745984" dbid="21" objectname="ReportServerTempDB.dbo.SessionData" indexname="IDX_SessionData" id="lock45662aca500" mode="X" associatedObjectId="72057594040745984">
      <owner-list>
        <owner id="process701f434d468" mode="S" requestType="wait" />
      </owner-list>
      <waiter-list>
        <waiter id="process6bcd088eca8" mode="U" requestType="wait" />
      </waiter-list>
    </keylock>
  </resource-list>
</deadlock>');
-- Insert the deadlock XML in the above line!
-- Duplicate as necessary for additional graphs.

WITH CTE AS 
(
SELECT  DeadlockID,
        DeadlockGraph
FROM    @xml_report
), Victims AS 
(
SELECT    ID = Victims.List.value('@id', 'varchar(50)')
FROM      CTE
          CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/victim-list/victimProcess') AS Victims (List)
), Locks AS 
(
-- Merge all of the lock information together.
SELECT  CTE.DeadlockID,
        MainLock.Process.value('@id', 'varchar(100)') AS LockID,
        OwnerList.Owner.value('@id', 'varchar(200)') AS LockProcessId,
        REPLACE(MainLock.Process.value('local-name(.)', 'varchar(100)'), 'lock', '') AS LockEvent,
        MainLock.Process.value('@objectname', 'sysname') AS ObjectName,
        OwnerList.Owner.value('@mode', 'varchar(10)') AS LockMode,
        MainLock.Process.value('@dbid', 'INTEGER') AS Database_id,
        MainLock.Process.value('@associatedObjectId', 'BIGINT') AS AssociatedObjectId,
        MainLock.Process.value('@WaitType', 'varchar(100)') AS WaitType,
        WaiterList.Owner.value('@id', 'varchar(200)') AS WaitProcessId,
        WaiterList.Owner.value('@mode', 'varchar(10)') AS WaitMode
FROM    CTE
        CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/resource-list') AS Lock (list)
        CROSS APPLY Lock.list.nodes('*') AS MainLock (Process)
        OUTER APPLY MainLock.Process.nodes('owner-list/owner') AS OwnerList (Owner)
        CROSS APPLY MainLock.Process.nodes('waiter-list/waiter') AS WaiterList (Owner)
), Process AS 
(
-- get the data from the process node
SELECT  CTE.DeadlockID,
        [Victim] = CONVERT(BIT, CASE WHEN Deadlock.Process.value('@id', 'varchar(50)') = ISNULL(Deadlock.Process.value('../../@victim', 'varchar(50)'), v.ID) 
                                     THEN 1
                                     ELSE 0
                                END),
        [LockMode] = Deadlock.Process.value('@lockMode', 'varchar(10)'), -- how is this different from in the resource-list section?
        [ProcessID] = Process.ID, --Deadlock.Process.value('@id', 'varchar(50)'),
        [KPID] = Deadlock.Process.value('@kpid', 'int'), -- kernel-process id / thread ID number
        [SPID] = Deadlock.Process.value('@spid', 'int'), -- system process id (connection to sql)
        [SBID] = Deadlock.Process.value('@sbid', 'int'), -- system batch id / request_id (a query that a SPID is running)
        [ECID] = Deadlock.Process.value('@ecid', 'int'), -- execution context ID (a worker thread running part of a query)
        [IsolationLevel] = Deadlock.Process.value('@isolationlevel', 'varchar(200)'),
        [WaitResource] = Deadlock.Process.value('@waitresource', 'varchar(200)'),
        [LogUsed] = Deadlock.Process.value('@logused', 'int'),
        [ClientApp] = Deadlock.Process.value('@clientapp', 'varchar(100)'),
        [HostName] = Deadlock.Process.value('@hostname', 'varchar(20)'),
        [LoginName] = Deadlock.Process.value('@loginname', 'varchar(20)'),
        [TransactionTime] = Deadlock.Process.value('@lasttranstarted', 'datetime'),
        [BatchStarted] = Deadlock.Process.value('@lastbatchstarted', 'datetime'),
        [BatchCompleted] = Deadlock.Process.value('@lastbatchcompleted', 'datetime'),
        [InputBuffer] = Input.Buffer.query('.'),
        CTE.[DeadlockGraph],
        es.ExecutionStack,
        [SQLHandle] = ExecStack.Stack.value('@sqlhandle', 'varchar(64)'),
        [QueryStatement] = NULLIF(ExecStack.Stack.value('.', 'varchar(max)'), ''),
        --[QueryStatement] = Execution.Frame.value('.', 'varchar(max)'),
        [ProcessQty] = SUM(1) OVER (PARTITION BY CTE.DeadlockID),
        [TranCount] = Deadlock.Process.value('@trancount', 'int'),
		[TransactionID] = Deadlock.Process.value('@xactid', 'bigint')
FROM    CTE
        CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/process-list/process') AS Deadlock (Process)
        CROSS APPLY (SELECT Deadlock.Process.value('@id', 'varchar(50)') ) AS Process (ID)
        LEFT JOIN Victims v ON Process.ID = v.ID
        CROSS APPLY Deadlock.Process.nodes('inputbuf') AS Input (Buffer)
        CROSS APPLY Deadlock.Process.nodes('executionStack') AS Execution (Frame)
-- get the data from the executionStack node as XML
        CROSS APPLY (SELECT ExecutionStack = (SELECT   ProcNumber = ROW_NUMBER() 
                                                                    OVER (PARTITION BY CTE.DeadlockID,
                                                                                       Deadlock.Process.value('@id', 'varchar(50)'),
                                                                                       Execution.Stack.value('@procname', 'sysname'),
                                                                                       Execution.Stack.value('@code', 'varchar(MAX)') 
                                                                              ORDER BY (SELECT 1)),
                                                        ProcName = Execution.Stack.value('@procname', 'sysname'),
                                                        Line = Execution.Stack.value('@line', 'int'),
                                                        SQLHandle = Execution.Stack.value('@sqlhandle', 'varchar(64)'),
                                                        Code = LTRIM(RTRIM(Execution.Stack.value('.', 'varchar(MAX)')))
                                                FROM Execution.Frame.nodes('frame') AS Execution (Stack)
                                                ORDER BY ProcNumber
                                                FOR XML PATH('frame'), ROOT('executionStack'), TYPE )
                    ) es
        CROSS APPLY Execution.Frame.nodes('frame') AS ExecStack (Stack)
)
     -- get the columns in the desired order
--SELECT * FROM Locks

SELECT  p.DeadlockID,
        p.Victim,
        p.ProcessQty,
        ProcessNbr = DENSE_RANK() 
                     OVER (PARTITION BY p.DeadlockId 
                               ORDER BY p.ProcessID),
        p.LockMode,
        LockedObject = NULLIF(l.ObjectName, ''),
        l.database_id,
		p.TransactionID,
        l.AssociatedObjectId,
        LockProcess = p.ProcessID,
        p.KPID,
        p.SPID,
        p.SBID,
        p.ECID,
        p.TranCount,
        l.LockEvent,
        LockedMode = l.LockMode,
        l.WaitProcessID,
        l.WaitMode,
        p.WaitResource,
        l.WaitType,
        p.IsolationLevel,
        p.LogUsed,
        p.ClientApp,
        p.HostName,
        p.LoginName,
        p.TransactionTime,
        p.BatchStarted,
        p.BatchCompleted,
        p.QueryStatement,
        p.SQLHandle,
        p.InputBuffer,
        p.DeadlockGraph,
        p.ExecutionStack
FROM    Process p
        LEFT JOIN Locks l
        --JOIN Process p
            ON p.DeadlockID = l.DeadlockID
               AND p.ProcessID = l.LockProcessID
ORDER BY p.DeadlockId,
        p.Victim DESC,
        p.ProcessId;
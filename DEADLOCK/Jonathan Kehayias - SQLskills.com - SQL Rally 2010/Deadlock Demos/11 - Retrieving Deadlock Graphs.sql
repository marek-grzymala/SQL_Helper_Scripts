/*============================================================================
  File:     11-Retrieving Deadlock Graphs.sql

  Summary:	Demonstrates how to retrieve deadlock graph information from
			SQL Server based on the capture methods demonstrated in script
			2-Setup Deadlock Captures.sql.

  Date:     May 2011

  SQL Server Version: 
		2005, 2008, 2008R2
------------------------------------------------------------------------------
  Written by Jonathan M. Kehayias, SQLskills.com
	
  (c) 2011, SQLskills.com. All rights reserved.

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/



USE [DeadlockDemo];
GO
-- Demo extracting Deadlock Graphs from Profiler Trace!

	-- File->Export->Extract SQL Server Events->Extract Deadlock Events

-- Demo Trace Flag 1222 output from ErrorLog
EXECUTE xp_readerrorlog;

-- Demo Event Notification capture
	-- View the queue information
	SELECT * 
	FROM DeadlockGraphQueue

	-- Process the Event Notification Queue
	DECLARE @deadlock XML,
			@victim varchar(50), 
			@victimplan XML, 
			@contribplan XML;

	-- Handle one message at a time		
	RECEIVE TOP(1) 
			@deadlock = CAST(message_body AS XML).query('/EVENT_INSTANCE/TextData/*')
	FROM dbo.DeadlockGraphQueue;	

	-- Determine the victim from the graph		
	SELECT @victim = @deadlock.value('(deadlock-list/deadlock/@victim)[1]', 'varchar(50)');

	-- Get the victim plan
	SELECT @victimplan = [query_plan] 
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_query_plan([plan_handle])
	WHERE [sql_handle] = @deadlock.value('xs:hexBinary(substring((
		deadlock-list/deadlock/process-list/process[@id=sql:variable("@victim")]/executionStack/frame/@sqlhandle)[1], 
		3))', 'varbinary(max)');
		
	-- Get the contributing query plan
	SELECT @contribplan = [query_plan] 
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_query_plan([plan_handle])
	WHERE [sql_handle] = @deadlock.value('xs:hexBinary(substring((
		deadlock-list/deadlock/process-list/process[@id!=sql:variable("@victim")]/executionStack/frame/@sqlhandle)[1],
		 3))', 'varbinary(max)');

	-- Return the result
	SELECT @deadlock AS DeadlockGraph, 
		   @victimplan AS VictimPlan, 
		   @contribplan AS ContribPlan;

-- Retrieve from Extended Events
SELECT CAST(XEvent.value('(event/data/value)[1]', 'varchar(max)')AS XML) as DeadlockGraph
FROM
(SELECT 
    XEvent.query('.') AS XEvent
 FROM    (SELECT CAST(target_data AS XML) AS TargetData
         FROM sys.dm_xe_session_targets st
         JOIN sys.dm_xe_sessions s 
            ON s.address = st.event_session_address
         WHERE s.name = 'system_health'
           AND st.target_name = 'ring_buffer') AS Data
 CROSS APPLY TargetData.nodes ('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData (XEvent)
) AS src;

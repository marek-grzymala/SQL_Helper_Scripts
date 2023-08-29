/*============================================================================
  File:     2-Setup Deadlock Captures.sql

  Summary:	Sets up a SQL instance to capture deadlock information using 
			SQL Profiler (manually setup), Trace Flag 1222 to the ErrorLog,
			and Event Notifications to a Service Broker Queue.

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

USE [DeadlockDemo]
GO

-- Demonstrate Deadlock Trace Setup with Profiler!


-- Enable Deadlock Graph Capture with Trace Flag to ErrorLog
	DBCC TRACEON(1222, -1)


-- Setup Event Notification for Deadlock Capture
	--  Create a service broker queue to hold the events
	CREATE QUEUE DeadlockGraphQueue
	GO

	--  Create a service broker service receive the events
	CREATE SERVICE DeadlockGraphService
		ON QUEUE DeadlockGraphQueue ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
	GO

	-- Create the event notification for deadlock graphs on the service
	CREATE EVENT NOTIFICATION CaptureDeadlocks
		ON SERVER
		WITH FAN_IN
		FOR DEADLOCK_GRAPH
		TO SERVICE 'DeadlockGraphService', 'current database';
	GO

	-- Query the catalog to see the notification
	SELECT * 
	FROM sys.server_event_notifications 


/*============================================================================
  File:     Reset Script.sql

  Summary:	Script to reset the environment after running demos.

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
DROP EVENT NOTIFICATION CaptureDeadlocks ON SERVER
DROP SERVICE DeadlockGraphservice
DROP QUEUE DeadlockGraphQueue
GO
USE [master]
GO
ALTER DATABASE [DeadlockDemo] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE [DeadlockDemo]
GO
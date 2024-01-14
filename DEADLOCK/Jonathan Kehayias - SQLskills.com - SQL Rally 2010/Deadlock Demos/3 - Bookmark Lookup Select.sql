/*============================================================================
  File:     3-Bookmark Lookup Select.sql

  Summary:	Process that performs a looping SELECT from the bookmark lookup
			demo tables to trigger a deadlock.  This script runs in one
			window while the 4-Bookmark Lookup Update.sql script runs in a 
			separate window to actually trigger the deadlock.

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

SET NOCOUNT ON
IF OBJECT_ID('tempdb..#t1') IS NOT NULL
BEGIN 
	DROP TABLE #t1
END
CREATE TABLE #t1 (col2 INT, col3 INT)
GO
WHILE (1=1) 
BEGIN
    INSERT INTO #t1 EXEC usp_BookmarkLookupSelect 4
    TRUNCATE TABLE #t1
END
GO

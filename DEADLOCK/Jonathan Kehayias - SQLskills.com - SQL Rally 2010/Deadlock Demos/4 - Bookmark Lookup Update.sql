/*============================================================================
  File:     4-Bookmark Lookup Update.sql

  Summary:	Process that performs a looping UPDATE from the bookmark lookup
			demo tables to trigger a deadlock.  This script runs in one
			window while the 3-Bookmark Lookup Select.sql script runs in a 
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

USE DeadlockDemo
GO
SET NOCOUNT ON
WHILE (1=1) 
BEGIN
    EXEC BookmarkLookupUpdate 4
END
GO
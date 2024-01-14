/*============================================================================
  File:     1-Bookmark Lookup Setup.sql

  Summary:	Creates a database, table, and two stored procedures to allow
			a bookmark lookup deadlock to be created in SQL Server.

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
USE [master]
GO


IF DB_ID('DeadlockDemo') IS NOT NULL 
BEGIN
	ALTER DATABASE DeadlockDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE DeadlockDemo	
END
GO

CREATE DATABASE DeadlockDemo
GO

SET NOCOUNT ON
GO

USE [DeadlockDemo]
GO

IF OBJECT_ID ('BookmarkLookupDeadlock') IS NOT NULL DROP TABLE BookmarkLookupDeadlock
IF OBJECT_ID ('BookmarkLookupSelect') IS NOT NULL DROP PROC BookmarkLookupSelect
IF OBJECT_ID ('BookmarkLookupUpdate') IS NOT NULL DROP PROC BookmarkLookupUpdate
GO
CREATE TABLE BookmarkLookupDeadlock (col1 int, col2 int, col3 int, col4 char(100))
GO
DECLARE @int int
SET @int = 1
WHILE (@int <= 1000) BEGIN
    INSERT INTO BookmarkLookupDeadlock VALUES (@int*2, @int*2, @int*2, @int*2)
    SET @int = @int + 1
END
GO
CREATE CLUSTERED INDEX cidx_BookmarkLookupDeadlock ON BookmarkLookupDeadlock (col1)
CREATE NONCLUSTERED INDEX idx_BookmarkLookupDeadlock_col2 ON BookmarkLookupDeadlock (col2)
GO

CREATE OR ALTER PROC usp_BookmarkLookupSelect 
@col2 INT 
--WITH ENCRYPTION
AS 
BEGIN
    SELECT col2, col3 FROM BookmarkLookupDeadlock WHERE col2 BETWEEN @col2 AND @col2+1
END
GO

CREATE OR ALTER PROC usp_BookmarkLookupUpdate 
@col2 int 
--WITH ENCRYPTION
AS
BEGIN
    UPDATE BookmarkLookupDeadlock SET col2 = col2+1 WHERE col1 = @col2
    UPDATE BookmarkLookupDeadlock SET col2 = col2-1 WHERE col1 = @col2
END
GO

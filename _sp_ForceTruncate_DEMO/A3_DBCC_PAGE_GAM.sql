USE [TestDB]
GO


/*
In any data file:
page no 0: file header 
page no 1: PFS (Page Free Space) page 
page no 2: GAM 
page no 3: SGAM page. 
*/
DECLARE 
@FileHeader INT = 0,
@PFS        INT = 1,
@GAM        INT = 2,
@SGAM       INT = 3;

DBCC PAGE(5, 1, @GAM, 2) WITH TABLERESULTS;
DBCC PAGE(5, 1, 8376, 2) WITH TABLERESULTS;

--SHUTDOWN WITH NOWAIT
--SELECT [sqlserver_start_time] FROM [sys].[dm_os_sys_info]
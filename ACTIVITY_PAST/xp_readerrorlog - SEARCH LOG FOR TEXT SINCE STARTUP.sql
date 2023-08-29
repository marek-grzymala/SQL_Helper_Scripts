SET NOCOUNT ON

DECLARE @SQL_Start_Date DATETIME, @now DATETIME
SELECT @SQL_Start_Date = DATEADD(MINUTE, -1, sqlserver_start_time), @now = GETDATE() FROM sys.dm_os_sys_info
SELECT @SQL_Start_Date AS [SQL Start Date]

DECLARE @maxLog      INT,
        @searchStr   VARCHAR(256),
        @startDate   DATETIME;

SELECT  @searchStr = 'Procedure', --'BUF', --'Database backed up. Database:'
        @startDate = DATEADD(HOUR, -12, @now) --@SQL_Start_Date --'2013-10-01 08:00';

DECLARE @errorLogs   TABLE (
    LogID    INT,
    LogDate  DATETIME,
    LogSize  BIGINT   );

DECLARE @logData      TABLE (
    LogDate     DATETIME,
    ProcInfo    VARCHAR(64),
    LogText     VARCHAR(2048)   );

INSERT INTO @errorLogs EXEC sys.sp_enumerrorlogs;
--SELECT * FROM @errorLogs
SELECT TOP 1 @maxLog = LogID FROM @errorLogs WHERE [LogDate] <= @startDate ORDER BY [LogDate] DESC;

WHILE @maxLog >= 0
BEGIN
    INSERT INTO @logData
    EXEC sys.sp_readerrorlog @maxLog, 1, @searchStr;
    SET @maxLog = @maxLog - 1;
END

SELECT [LogDate], [LogText]
FROM @logData
WHERE [LogDate] >= @startDate
ORDER BY [LogDate] DESC;

/*
-- compare value for Large Pages Allocated above to large_page_allocations_MB below:
SELECT 
	large_page_allocations_kb/1024		AS [large_page_allocations_MB] 
	, locked_page_allocations_kb/1024	AS [locked_page_allocations_MB]
FROM sys.dm_os_process_memory

*/

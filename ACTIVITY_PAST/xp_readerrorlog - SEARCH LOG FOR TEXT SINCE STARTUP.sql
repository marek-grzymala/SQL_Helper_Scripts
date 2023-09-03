SET NOCOUNT ON

DECLARE @SQL_Start_Date DATETIME
      , @now            DATETIME

SELECT @SQL_Start_Date = DATEADD(MINUTE, -1, [sqlserver_start_time])
	 , @now = GETDATE()
FROM [sys].[dm_os_sys_info]
--SELECT @SQL_Start_Date AS [SQL Start Date]

DECLARE @maxLog    INT
      , @searchStr VARCHAR(256)
      , @startDate DATETIME;

SELECT @searchStr = 'dedicated'
     , @startDate = DATEADD(DAY, -1, @now)

DECLARE @errorLogs TABLE ([LogID] INT, [LogDate] DATETIME, [LogSize] BIGINT);

DECLARE @logData TABLE ([LogId] INT NOT NULL, [LogDate] DATETIME NOT NULL, [ProcInfo] VARCHAR(64), [LogText] VARCHAR(2048));
DECLARE @logDataTmp TABLE ([LogDate] DATETIME, [ProcInfo] VARCHAR(64), [LogText] VARCHAR(2048));

INSERT INTO @errorLogs EXEC sys.sp_enumerrorlogs;

SELECT TOP 1
       @maxLog = [LogID]
FROM @errorLogs
--WHERE [LogDate] <= @startDate 
ORDER BY [LogDate];

WHILE @maxLog >= 0
BEGIN
    DELETE FROM @logDataTmp
	INSERT INTO @logDataTmp EXEC sys.sp_readerrorlog @maxLog, 1, @searchStr;
    PRINT(CONCAT('@maxLog: ', @maxLog))
	IF EXISTS (SELECT 1 FROM @logDataTmp)
	BEGIN
		INSERT INTO @logData
		SELECT @maxLog, [tmp].[LogDate], [tmp].[ProcInfo], [tmp].[LogText]        
		FROM @logDataTmp AS tmp
	END
    SET @maxLog = @maxLog - 1;
END

SELECT [LogId], [LogText] 
FROM @logData 
--WHERE [LogDate] >= @startDate ORDER BY [LogDate] DESC;

/*
-- compare value for Large Pages Allocated above to large_page_allocations_MB below:
SELECT 
	large_page_allocations_kb/1024		AS [large_page_allocations_MB] 
	, locked_page_allocations_kb/1024	AS [locked_page_allocations_MB]
FROM sys.dm_os_process_memory

*/

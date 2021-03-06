USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_Populate_ETL_Stats_AvgFinishTime_Task]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [qv].[usp_Populate_ETL_Stats_AvgFinishTime_Task] 
@SystemName NVARCHAR(64)
AS
BEGIN

SET NOCOUNT ON;

DECLARE @CheckParameterResult BIT = 0, @SystemKey INT

EXEC [qv].[usp_GetSystemKeyFromName] @_SystemName = @SystemName, @_CallingProcName = 'usp_Populate_ETL_Stats_AvgFinishTime_Task', @_CheckResult = @CheckParameterResult OUTPUT, @_SystemKey = @SystemKey OUTPUT
IF (@CheckParameterResult = 0)
BEGIN
	RETURN
END


	DECLARE @_SystemName NVARCHAR(64), @_ProcessName NVARCHAR(1024), @NumDaysBack INT
	SET @_SystemName = @SystemName
	
	DECLARE ProcessNames_Cursor CURSOR FOR
	SELECT DISTINCT([ProcessName]) 
	FROM 
		[qv].[ETL_Stats_LastRunTaskList] tl
		INNER JOIN [qv].[dim_aon_system] s ON s.[dim_aon_system_key] = tl.[SystemKey]
	WHERE 
		tl.[ChildTaskName] IS NOT NULL AND s.[dim_aon_system_key] = @SystemKey --s.[systemname] = @SystemName
		AND ((tl.[ProcessName] NOT LIKE 'ManualProcess%') AND (tl.[ProcessName] NOT LIKE 'DailyProcess_Only_Revenue_Split%'))

	DECLARE @TimeRecorded DATETIME = GETDATE()
	
	IF OBJECT_ID('TempDb..#AvgAdjustedResults_PerTask') IS NOT NULL DROP TABLE #AvgAdjustedResults_PerTask
	CREATE TABLE #AvgAdjustedResults_PerTask (ProcessName NVARCHAR(1024), NumDaysBack INT, AvgAdjusted TIME)
	
	OPEN ProcessNames_Cursor
	FETCH NEXT FROM ProcessNames_Cursor INTO @_ProcessName
	WHILE @@FETCH_STATUS = 0
	
	BEGIN
	
		TRUNCATE TABLE #AvgAdjustedResults_PerTask
		INSERT INTO #AvgAdjustedResults_PerTask (ProcessName, NumDaysBack) VALUES (@_ProcessName, -7)
		INSERT INTO #AvgAdjustedResults_PerTask (ProcessName, NumDaysBack) VALUES (@_ProcessName, -14)
		INSERT INTO #AvgAdjustedResults_PerTask (ProcessName, NumDaysBack) VALUES (@_ProcessName, -30)
	
			DECLARE DaysBack_Cursor CURSOR FOR
			SELECT NumDaysBack FROM #AvgAdjustedResults_PerTask
	
				OPEN DaysBack_Cursor
				FETCH NEXT FROM DaysBack_Cursor INTO @NumDaysBack
				WHILE @@FETCH_STATUS = 0 
				BEGIN
	
						PRINT @_ProcessName
						DECLARE @Avg TIME
						EXEC [qv].[usp_CalculateAvgPerProcess] @SystemName = @_SystemName, @ProcessName = @_ProcessName, @DaysBack = @NumDaysBack, @AvgAdjusted = @Avg OUTPUT
	
						UPDATE #AvgAdjustedResults_PerTask SET AvgAdjusted = @Avg WHERE NumDaysBack = @NumDaysBack
						FETCH NEXT FROM DaysBack_Cursor INTO @NumDaysBack
				
				END
			CLOSE DaysBack_Cursor  
			DEALLOCATE DaysBack_Cursor
	
			INSERT INTO [qv].[ETL_Stats_AvgFinishTime_Task] ([SystemKey], [TimeRecorded], [ProcessName], [7-DayAverage], [14-DayAverage], [30-DayAverage])
			(
				SELECT
					s.dim_aon_system_key, @TimeRecorded AS [TimeRecorded], @_ProcessName, PvtTbl.[-7], PvtTbl.[-14], PvtTbl.[-30]
				FROM
				  (
					SELECT NumDaysBack, AvgAdjusted FROM #AvgAdjustedResults_PerTask 
				  ) SourceTable
				PIVOT 
				  (
					Max([AvgAdjusted]) -- <== column to show values in the pivoted table
					FOR [NumDaysBack] IN ([-7], [-14], [-30])
				  ) AS PvtTbl
				INNER JOIN [qv].[dim_aon_system] s ON s.[dim_aon_system_key] = @SystemKey --s.systemname = @_SystemName
			)
	
	FETCH NEXT FROM ProcessNames_Cursor INTO @_ProcessName
	END
	CLOSE ProcessNames_Cursor  
	DEALLOCATE ProcessNames_Cursor

END
GO

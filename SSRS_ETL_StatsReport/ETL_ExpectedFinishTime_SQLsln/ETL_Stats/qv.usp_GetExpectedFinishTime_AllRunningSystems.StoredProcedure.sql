USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_GetExpectedFinishTime_AllRunningSystems]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [qv].[usp_GetExpectedFinishTime_AllRunningSystems]
AS
BEGIN
SET NOCOUNT ON;

IF OBJECT_ID('TempDb..#RunningSystems') IS NOT NULL DROP TABLE #RunningSystems
CREATE TABLE #RunningSystems (SystemName NVARCHAR(64), SystemKey INT)

IF OBJECT_ID('TempDb..#RunningSystems_ExpectedFinish') IS NOT NULL DROP TABLE #RunningSystems_ExpectedFinish
CREATE TABLE #RunningSystems_ExpectedFinish (
												[SystemName]					NVARCHAR(64)
												, [dim_aon_system_key]			INT
												, [ProcessName]					NVARCHAR(256)
												, [TaskStartTime]				TIME
												, [Task_7DAv_Diff]				INT
												, [Task_14DAv_Diff]				INT
												, [Task_30DAv_Diff]				INT
												, [System_7D_ExpectedFinish]	TIME
												, [System_14D_ExpectedFinish]	TIME
												, [System_30D_ExpectedFinish]	TIME
											)

;WITH RunningSystemsList AS
	(
		SELECT DISTINCT lt.[SystemKey] FROM [WYNWIPDB001050].[AON_MI_DWH].[dbo].[LogTable] lt (NOLOCK)
			INNER JOIN [qv].[dim_aon_system] s ON s.[dim_aon_system_key] = lt.[SystemKey] 
			WHERE 
					lt.[SystemKey] > 0 AND lt.[Status] <> 'SUCCESS' --= 'RUNNING' --
					AND lt.ProcessStartTime > (SELECT CAST(GETDATE()-1 AS DATE)) --<== some processes are stuck in the LogTable in RUNNING state forever
					AND ((lt.[ProcessName] NOT LIKE 'ManualProcess%') AND (lt.[ProcessName] NOT LIKE 'DailyProcess_Only_Revenue_Split%'))
		UNION
		SELECT DISTINCT lt.[SystemKey] FROM [WYNWIPDB001050].[ACIA_DWH].[dbo].[LogTable] lt (NOLOCK)
			INNER JOIN [qv].[dim_aon_system] s ON s.[dim_aon_system_key] = lt.[SystemKey] 
			WHERE 
					lt.[SystemKey] > 0 AND lt.[Status] <> 'SUCCESS' --= 'RUNNING' --
					AND lt.ProcessStartTime > (SELECT CAST(GETDATE()-1 AS DATE)) --<== some processes are stuck in the LogTable in RUNNING state forever
					AND (lt.[ProcessName] NOT LIKE 'ManualProcess%')
	)			

INSERT INTO #RunningSystems (SystemName, SystemKey)
(
		SELECT 
					  s.[systemname] 
					, rs.[SystemKey]
		FROM		RunningSystemsList rs
		INNER JOIN	[qv].dim_aon_system s ON s.[dim_aon_system_key] = rs.[SystemKey]
		WHERE		s.[ActiveForStats] = 1
)
--SELECT * FROM #RunningSystems

DECLARE RunningSystems_Cursor CURSOR FOR SELECT * FROM #RunningSystems
DECLARE @_SystemName NVARCHAR(64), @_SystemKey INT

	OPEN RunningSystems_Cursor
	FETCH NEXT FROM RunningSystems_Cursor INTO @_SystemName, @_SystemKey
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO #RunningSystems_ExpectedFinish EXECUTE [qv].[usp_GetExpectedFinishTime_PerSystem] @SystemKey = @_SystemKey --@SystemName = @_SystemName
		--EXECUTE [qv].[usp_GetExpectedFinishTime_PerSystem] @SystemName = @_SystemName
		FETCH NEXT FROM RunningSystems_Cursor INTO @_SystemName, @_SystemKey
	END
	CLOSE RunningSystems_Cursor  
	DEALLOCATE RunningSystems_Cursor


SELECT 
				[SystemName]
			,	[dim_aon_system_key]
			,	[ProcessName]
			,	CONVERT(TIME(0),[TaskStartTime],0)						AS [Task Start Time]
			,	[Task_7DAv_Diff]  
			,	[Task_14DAv_Diff] 
			,	[Task_30DAv_Diff]

			, CONVERT(TIME(0),[System_7D_ExpectedFinish] , 0)              AS [System_7D_ExpectedFinish]
			, CONVERT(TIME(0),[System_14D_ExpectedFinish], 0)              AS [System_14D_ExpectedFinish]
			, CONVERT(TIME(0),[System_30D_ExpectedFinish], 0)              AS [System_30D_ExpectedFinish]

			--,	CONVERT(TIME(0),[System_7_ExpectedFinish],0)				AS [System_7_ExpectedFinish]
			--,	CONVERT(TIME(0),[System_14_ExpectedFinish],0)				AS [System_14_ExpectedFinish]
			--,	CONVERT(TIME(0),[System_30_ExpectedFinish],0)				AS [System_30_ExpectedFinish]

			--,	CONVERT(TIME(0), DATEADD(MINUTE, (-1*[Task_7DAv_Diff] ), [System_7D_ExpectedFinish]), 0)	AS [System_7D_ExpectedFinish]
			--,	CONVERT(TIME(0), DATEADD(MINUTE, (-1*[Task_14DAv_Diff]), [System_14D_ExpectedFinish]), 0)	AS [System_14D_ExpectedFinish]
			--,	CONVERT(TIME(0), DATEADD(MINUTE, (-1*[Task_30DAv_Diff]), [System_30D_ExpectedFinish]), 0)	AS [System_30D_ExpectedFinish]


FROM #RunningSystems_ExpectedFinish

END
GO

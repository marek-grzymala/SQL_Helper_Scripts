USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_GetProcessExecHistory]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [qv].[usp_GetProcessExecHistory]
@DaysBack INT, @SystemKey INT = NULL, @ProcessName NVARCHAR(1024) = NULL, @StartDate DATETIME = NULL, @EndDate DATETIME = NULL
AS
BEGIN

DECLARE @SystemName NVARCHAR(64),
		@ErMessage NVARCHAR(2048),
		@ErSeverity INT,
		@ErState INT

IF ((@DaysBack IS NULL) AND (@StartDate IS NULL OR @EndDate IS NULL))
BEGIN
		SELECT
		   @ErMessage = 'You have to supply either @DaysBack parameter or both @StartDate and @EndDate.',
		   @ErSeverity = 15, --ERROR_SEVERITY(),
		   @ErState = ERROR_STATE()
		 
		RAISERROR (@ErMessage, @ErSeverity, @ErState)
		RETURN
END


IF ((@DaysBack IS NOT NULL) AND (@StartDate IS NULL OR @EndDate IS NULL))
BEGIN
	SET @StartDate	= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE())+@DaysBack, 0)
	SET @EndDate	= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE())+1, 0)
END


-- ALL SYSTEMS ON AON_MI_DWH:
-- //////////////////// @SystemName = 'Broaksure'				=> SystemKey = 115
-- //////////////////// @SystemName = 'Pure'					=> SystemKey = 110
-- //////////////////// @SystemName = 'MGA'						=> SystemKey = 122
-- //////////////////// @SystemName = 'ActivityTracker'			=> SystemKey = 1003

IF ((@SystemKey = 115) OR (@SystemKey = 110) OR (@SystemKey = 122) OR (@SystemKey = 1003))
	BEGIN
		SELECT 
					  lt.[LogID]
					, lt.[SystemKey]
					, lt.[RunID]
					, CONVERT(VARCHAR(19), lt.[ProcessStartTime], 120)						AS [ProcessStartTime]
					, CONVERT(VARCHAR(19), lt.[ProcessEndTime], 120)						AS [ProcessEndTime]
					, CONVERT(TIME(0),[ProcessDuration],0)									AS [ProcessDuration]
					, CONVERT(BIGINT,DATEDIFF(ss, 0, lt.[ProcessDuration]))					AS [ProcessDurationSec]
					, CONVERT(TIME, CONVERT(VARCHAR(8), lt.[ProcessStartTime],108))			AS [Start_TimeOnly]
					, CONVERT(TIME, CONVERT(VARCHAR(8), lt.[ProcessEndTime],108))			AS [End_TimeOnly]
					
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumInserts
						ELSE lt.[InsertCount]  END											AS [InsertCount]
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumUpdates
						ELSE lt.[UpdateCount]  END											AS [UpdateCount]
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumDeletes
						ELSE lt.[DeleteCount]  END											AS [DeleteCount]

					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumAllRecords
						ELSE 
							(
								CASE CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
								WHEN 0 THEN NULL 
								ELSE (COALESCE(lt.[InsertCount], 0)+COALESCE(lt.[UpdateCount], 0)+COALESCE(lt.[DeleteCount], 0))/CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
								END  
							)
						END																	AS [RecordsPerSecond]
					
		FROM		[qv].[LogTable] lt
		CROSS APPLY [qv].[ufn_GetSumRecordsPerSecond_PerSystem](lt.[SystemKey], lt.RunID) rps
		  
		WHERE 
					[ProcessName] = @ProcessName
					AND [SystemKey] = @SystemKey
					AND CAST([ProcessStartTime] AS DATE)	>= @StartDate
					AND CAST([ProcessEndTime] AS DATE)		<= @EndDate

		ORDER BY	[RunID] DESC
	END
ELSE
	BEGIN
		SELECT 
					  lt.[LogID]
					, lt.[SystemKey]
					, lt.[RunID]
					, CONVERT(VARCHAR(19), lt.[ProcessStartTime], 120)						AS [ProcessStartTime]
					, CONVERT(VARCHAR(19), lt.[ProcessEndTime], 120)						AS [ProcessEndTime]
					, CONVERT(TIME(0),[ProcessDuration],0)									AS [ProcessDuration]
					, CONVERT(BIGINT,DATEDIFF(ss, 0, lt.[ProcessDuration]))					AS [ProcessDurationSec]
					, CONVERT(TIME, CONVERT(VARCHAR(8), lt.[ProcessStartTime],108))			AS [Start_TimeOnly]
					, CONVERT(TIME, CONVERT(VARCHAR(8), lt.[ProcessEndTime],108))			AS [End_TimeOnly]

					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumInserts
						ELSE lt.[InsertCount]  END											AS [InsertCount]
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumUpdates
						ELSE lt.[UpdateCount]  END											AS [UpdateCount]
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumDeletes
						ELSE lt.[DeleteCount]  END											AS [DeleteCount]
					
					, CASE @ProcessName
						WHEN 'DailyProcess' THEN rps.SumAllRecords
						ELSE 
							(
								CASE CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
								WHEN 0 THEN NULL 
								ELSE (COALESCE(lt.[InsertCount], 0)+COALESCE(lt.[UpdateCount], 0)+COALESCE(lt.[DeleteCount], 0))/CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
								END  
							)
						END																	AS [RecordsPerSecond]
		
		FROM		[qv].[LogTable_ACIA] lt
		CROSS APPLY [qv].[ufn_GetSumRecordsPerSecond_PerSystem](lt.[SystemKey], lt.RunID) rps
		  
		WHERE 
					[ProcessName] = @ProcessName
					AND [SystemKey] = @SystemKey
					AND CAST([ProcessStartTime] AS DATE)	>= @StartDate
					AND CAST([ProcessEndTime] AS DATE)		<= @EndDate

		ORDER BY	[RunID] DESC
	END
END
GO

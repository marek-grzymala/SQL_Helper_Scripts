USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_Populate_ETL_Stats_AvgFinishTime_System]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [qv].[usp_Populate_ETL_Stats_AvgFinishTime_System] 
	-- Add the parameters for the stored procedure here
@SystemName NVARCHAR(64)
AS
BEGIN

SET NOCOUNT ON;

DECLARE @CheckParameterResult BIT = 0, @SystemKey INT

EXEC [qv].[usp_GetSystemKeyFromName] @_SystemName = @SystemName, @_CallingProcName = 'usp_Populate_ETL_Stats_AvgFinishTime_System', @_CheckResult = @CheckParameterResult OUTPUT, @_SystemKey = @SystemKey OUTPUT
IF (@CheckParameterResult = 0)
BEGIN
	RETURN
END
/*
EXEC [qv].[usp_CheckSystemName] @_SystemName = @SystemName, @_CallingProcName = 'usp_Populate_ETL_Stats_AvgFinishTime_System', @_CheckResult = @CheckParameterResult OUTPUT
IF (@CheckParameterResult = 0)
BEGIN
	RETURN
END
*/


	DECLARE @NumDaysBack INT
		IF OBJECT_ID('TempDb..#AvgAdjustedResults') IS NOT NULL DROP TABLE #AvgAdjustedResults
		CREATE TABLE #AvgAdjustedResults (NumDaysBack INT, AvgAdjusted TIME)
	
		INSERT INTO #AvgAdjustedResults (NumDaysBack) VALUES (-7)
		INSERT INTO #AvgAdjustedResults (NumDaysBack) VALUES (-14)
		INSERT INTO #AvgAdjustedResults (NumDaysBack) VALUES (-30)
	
		DECLARE @KeyTable TABLE (SystemKey INT)
		INSERT INTO @KeyTable SELECT @SystemKey --s.[dim_aon_system_key] FROM [dim_aon_system] s WHERE s.[systemname] = @SystemName
	
		DECLARE DaysBack_Cursor CURSOR FOR
		SELECT NumDaysBack FROM #AvgAdjustedResults
	
		OPEN DaysBack_Cursor
		FETCH NEXT FROM DaysBack_Cursor INTO @NumDaysBack
		WHILE @@FETCH_STATUS = 0 
		
				BEGIN
	
						IF OBJECT_ID('TempDb..#FinishTimeFullList') IS NOT NULL DROP TABLE #FinishTimeFullList
						CREATE TABLE #FinishTimeFullList (RunID INT, ProcessEndTime TIME)
						
-- ALL SYSTEMS ON AON_MI_DWH:
-- //////////////////// @SystemName = 'Broaksure'				=> SystemKey = 115
-- //////////////////// @SystemName = 'Pure'					=> SystemKey = 110
-- //////////////////// @SystemName = 'MGA'						=> SystemKey = 122
-- //////////////////// @SystemName = 'ActivityTracker'			=> SystemKey = 1003

						IF ((SELECT COUNT(SystemKey) FROM @KeyTable WHERE SystemKey IN (115, 110, 122, 1003)) > 0)
						BEGIN
										
								INSERT INTO #FinishTimeFullList (RunID, ProcessEndTime)
	
									SELECT
													lt.[RunID]
													, MAX(lt.[ProcessEndTime]) AS [ProcessEndTime]
	
									FROM			[qv].[LogTable] lt WITH(NOLOCK)
									INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK)
									ON				s.[dim_aon_system_key] = lt.[SystemKey]
								
									WHERE			CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @NumDaysBack)
													--AND CAST(lt.[ProcessStartTime] AS DATE) < DATEADD(DAY,0,DATEDIFF(DAY,0,GETDATE()))
													--AND s.[systemname] = @SystemName
													AND s.[dim_aon_system_key] = @SystemKey
													AND ((lt.[ProcessName] NOT LIKE 'ManualProcess%') AND (lt.[ProcessName] NOT LIKE 'DailyProcess_Only_Revenue_Split%'))
									GROUP BY		lt.[RunID]
									ORDER BY		[ProcessEndTime] DESC
						END
	
						IF ((SELECT COUNT(SystemKey) FROM @KeyTable WHERE SystemKey NOT IN (115, 110, 122, 1003)) > 0)
						BEGIN
										
								INSERT INTO #FinishTimeFullList (RunID, ProcessEndTime)
	
									SELECT
													lt.[RunID]
													, MAX(lt.[ProcessEndTime]) AS [ProcessEndTime]
	
									FROM			[qv].[LogTable_ACIA] lt WITH(NOLOCK)
									INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK)
									ON				s.[dim_aon_system_key] = lt.[SystemKey]
								
									WHERE			CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @NumDaysBack)
													--AND CAST(lt.[ProcessStartTime] AS DATE) < DATEADD(DAY,0,DATEDIFF(DAY,0,GETDATE()))
													--AND s.[systemname] = @SystemName
													AND s.[dim_aon_system_key] = @SystemKey
													AND lt.[ProcessName] NOT LIKE 'ManualProcess%'
									GROUP BY		lt.[RunID]
									ORDER BY		[ProcessEndTime] DESC
						END
	
						--SELECT * FROM #FinishTimeFullList
	
						-- calculate and store Average and StDev:
						DECLARE @AvgUnadjusted TIME, @StDevInMinutes INT
	
						SELECT @AvgUnadjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessEndTime]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
						FROM #FinishTimeFullList
	
						SELECT @StDevInMinutes = CAST(DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), CAST(DATEADD(MS, STDEVP(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessEndTime]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)) AS INT)
						FROM #FinishTimeFullList
	
						DECLARE @AvgAdjusted TIME
						SELECT 
	
									@AvgAdjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST(fl.[ProcessEndTime] AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
						FROM
									#FinishTimeFullList fl
	
						-- this predicate filters out records outside of range: Mean +/- Standard Devaition:
						WHERE 
	
									DATEDIFF(MINUTE, CAST(fl.[ProcessEndTime] AS TIME), @AvgUnadjusted) <= @StDevInMinutes AND
									DATEDIFF(MINUTE, CAST(fl.[ProcessEndTime] AS TIME), @AvgUnadjusted) >= @StDevInMinutes * -1
						--GROUP BY
						--			fl.RunID, fl.ProcessEndTime, [Averg], [StDev]
	
						--SELECT @AvgAdjusted AS [AdjustedAvgFinishTime]
						UPDATE #AvgAdjustedResults SET AvgAdjusted = @AvgAdjusted WHERE NumDaysBack = @NumDaysBack
				/*
						SELECT 
									fl.RunID,
									fl.ProcessEndTime,
									@AvgUnadjusted AS [@AvgUnadjusted],
									@StDevInMinutes AS [@StDevInMinutes],
									DATEDIFF(MINUTE, CAST(fl.ProcessEndTime AS TIME), @AvgUnadjusted) AS [Diff in Min From Averg]
						FROM
									#FinishTimeFullList fl
						WHERE 
									DATEDIFF(MINUTE, CAST(fl.[ProcessEndTime] AS TIME), @AvgUnadjusted) < @StDevInMinutes AND
									DATEDIFF(MINUTE, CAST(fl.[ProcessEndTime] AS TIME), @AvgUnadjusted) > @StDevInMinutes * -1
						GROUP BY
									fl.RunID,
									fl.ProcessEndTime	
				*/
						FETCH NEXT FROM DaysBack_Cursor INTO @NumDaysBack
				END
		CLOSE DaysBack_Cursor  
		DEALLOCATE DaysBack_Cursor
	
		--SELECT * FROM #AvgAdjustedResults 
		INSERT INTO [qv].[ETL_Stats_AvgFinishTime_System] ([SystemKey], [TimeRecorded], [7-DayAverage], [14-DayAverage], [30-DayAverage])
		(
			SELECT
				s.dim_aon_system_key, GETDATE() AS [TimeRecorded], PvtTbl.[-7], PvtTbl.[-14], PvtTbl.[-30]
			FROM
			  (
				SELECT NumDaysBack, AvgAdjusted FROM #AvgAdjustedResults 
			  ) SourceTable
			PIVOT 
			  (
				Max([AvgAdjusted]) -- <== column to show values in the pivoted table
				FOR [NumDaysBack] IN ([-7], [-14], [-30])
			  ) AS PvtTbl
			INNER JOIN [qv].[dim_aon_system] s ON s.[dim_aon_system_key] = @SystemKey --s.systemname = @SystemName
		)
END
GO

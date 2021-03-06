USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_CalculateAvgPerProcess]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [qv].[usp_CalculateAvgPerProcess] 
	-- Add the parameters for the stored procedure here
@SystemName NVARCHAR(64), @ProcessName NVARCHAR(256), @DaysBack INT, @AvgAdjusted TIME OUTPUT
AS
BEGIN
IF (@ProcessName NOT LIKE 'ManualProcess%')
BEGIN

SET NOCOUNT ON;

DECLARE @CheckParameterResult BIT = 0, @SystemKey INT

EXEC [qv].[usp_GetSystemKeyFromName] @_SystemName = @SystemName, @_CallingProcName = 'usp_CalculateAvgPerProcess', @_CheckResult = @CheckParameterResult OUTPUT, @_SystemKey = @SystemKey OUTPUT
IF (@CheckParameterResult = 0)
BEGIN
	RETURN
END

		IF OBJECT_ID('TempDb..#RunTimePerProcess_FullList') IS NOT NULL DROP TABLE #RunTimePerProcess_FullList
		CREATE TABLE #RunTimePerProcess_FullList ([LogID] BIGINT, [RunID] BIGINT, [ProcessName] NVARCHAR(256), [ProcessStartTime] DATETIME, [ProcessEndTime] DATETIME, [ProcessDuration] TIME)
		CREATE CLUSTERED INDEX [IX_LogID_RunID] ON #RunTimePerProcess_FullList
		(
			[LogID] ASC,
			[RunID] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
		
		DECLARE @KeyTable TABLE (SystemKey INT, LastRunID INT)
		INSERT INTO @KeyTable 
					SELECT		DISTINCT
								s.[dim_aon_system_key],
								MAX(r.[RunID])
					FROM
								[qv].[dim_aon_system] s 
					JOIN		[qv].[ETL_Stats_LastRunTaskList] r
					ON			r.[SystemKey] = s.[dim_aon_system_key]
					WHERE		s.[dim_aon_system_key] = @SystemKey
								--s.[systemname] = @SystemName
					GROUP BY	s.[dim_aon_system_key]
		
-- ALL SYSTEMS ON AON_MI_DWH:
-- //////////////////// @SystemName = 'Broaksure'				=> SystemKey = 115
-- //////////////////// @SystemName = 'Pure'					=> SystemKey = 110
-- //////////////////// @SystemName = 'MGA'						=> SystemKey = 122
-- //////////////////// @SystemName = 'ActivityTracker'			=> SystemKey = 1003
		IF (((SELECT COUNT(SystemKey) FROM @KeyTable WHERE SystemKey IN (115, 110, 122, 1003)) > 0) AND (@ProcessName NOT LIKE 'DailyProcess_Only_Revenue_Split%'))
		BEGIN
/*
		; WITH 
		LastRunTaskList AS
		(
			SELECT		rt.[ProcessName]
			FROM		[qv].[ETL_Stats_LastRunTaskList] rt
			WHERE		rt.[RunID] = (SELECT LastRunID FROM @KeyTable)
						AND rt.[ChildTaskName] IS NOT NULL 
		)
*/
					INSERT INTO #RunTimePerProcess_FullList([LogID], [RunID], [ProcessName], [ProcessStartTime], [ProcessEndTime], [ProcessDuration]) 
					(				
						SELECT
										  lt.[LogID]
										, lt.[RunID]
										, lt.[ProcessName]						AS [ProcessName]
										, lt.[ProcessStartTime]					AS [ProcessStartTime]
										, lt.[ProcessEndTime]					AS [ProcessEndTime]
										, lt.[ProcessDuration]					AS [ProcessDuration]
					
						FROM			[qv].[LogTable] lt WITH(NOLOCK)
						INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK) ON	s.[dim_aon_system_key] = lt.[SystemKey]
						--INNER JOIN		LastRunTaskList lr ON lr.ProcessName = lt.ProcessName
						
						WHERE			s.[dim_aon_system_key] = @SystemKey
										AND lt.[ProcessName] = @ProcessName
										AND DATEDIFF(DAY, CAST(lt.[ProcessStartTime] AS DATE), GETDATE()) <= (@DaysBack * -1)
										--AND CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @DaysBack)
										--AND CAST(lt.[ProcessStartTime] AS DATE) < DATEADD(d,0,DATEDIFF(d,0,GETDATE()))
						--ORDER BY lt.[ProcessStartTime] DESC
					)
		END
		
		-- ALL SYSTEMS ON ACIA_DWH:
		ELSE
		BEGIN
/*
		; WITH 
		LastRunTaskList AS
		(
			SELECT		rt.[ProcessName]
			FROM		[qv].[ETL_Stats_LastRunTaskList] rt
			WHERE		rt.[RunID] = (SELECT LastRunID FROM @KeyTable)
						AND rt.[ChildTaskName] IS NOT NULL 
		)
*/
					INSERT INTO #RunTimePerProcess_FullList([LogID], [RunID], [ProcessName], [ProcessStartTime], [ProcessEndTime], [ProcessDuration]) 
					(				
						SELECT
										  lt.[LogID]
										, lt.[RunID]
										, lt.[ProcessName]						AS [ProcessName]
										, lt.[ProcessStartTime]					AS [ProcessStartTime]
										, lt.[ProcessEndTime]					AS [ProcessEndTime]
										, lt.[ProcessDuration]					AS [ProcessDuration]
					
						FROM			[qv].[LogTable_ACIA] lt WITH(NOLOCK)
						INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK) ON	s.[dim_aon_system_key] = lt.[SystemKey]
						--INNER JOIN		LastRunTaskList lr ON lr.ProcessName = lt.ProcessName
						
						WHERE			s.[dim_aon_system_key] = @SystemKey
										AND lt.[ProcessName] = @ProcessName
										AND DATEDIFF(DAY, CAST(lt.[ProcessStartTime] AS DATE), GETDATE()) <= (@DaysBack * -1)
										--AND CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @DaysBack)
										--AND CAST(lt.[ProcessStartTime] AS DATE) < DATEADD(d,0,DATEDIFF(d,0,GETDATE()))
						--ORDER BY lt.[ProcessStartTime] DESC
					)
		END
		
		DECLARE @AvgUnadjusted TIME, @StDevInMinutes INT
		
		SELECT @AvgUnadjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessStartTime]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
		FROM #RunTimePerProcess_FullList
		
		SELECT @StDevInMinutes = CAST(DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), CAST(DATEADD(MS, STDEVP(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessStartTime]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)) AS INT)
		FROM #RunTimePerProcess_FullList
		
		
		IF (@StDevInMinutes = 0)
			SELECT @AvgAdjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST(fl.[ProcessStartTime] AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
			FROM 
			#RunTimePerProcess_FullList fl
		ELSE
		
		
		BEGIN
			SELECT 
						--fl.RunID,
						--fl.ProcessStartTime,
						@AvgAdjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST(fl.[ProcessStartTime] AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
						--@AvgUnadjusted  AS [AvgUnadjusted],
						--@StDevInMinutes AS [StDevInMinutes],
						--DATEDIFF(MINUTE, CAST(fl.ProcessStartTime AS TIME), @AvgUnadjusted) AS [Diff in Min From Averg]
			FROM 
						#RunTimePerProcess_FullList fl
			WHERE 
						DATEDIFF(MINUTE, CAST(fl.[ProcessStartTime] AS TIME), @AvgUnadjusted) <= @StDevInMinutes AND
						DATEDIFF(MINUTE, CAST(fl.[ProcessStartTime] AS TIME), @AvgUnadjusted) >= @StDevInMinutes * -1
		END
		    -- Insert statements for procedure here
		SELECT @AvgAdjusted --AS [AdjustedAvgFinishTime]
END
END
GO

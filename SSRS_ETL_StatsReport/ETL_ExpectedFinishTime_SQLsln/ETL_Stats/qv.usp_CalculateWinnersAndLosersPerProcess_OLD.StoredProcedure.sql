USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_CalculateWinnersAndLosersPerProcess_OLD]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [qv].[usp_CalculateWinnersAndLosersPerProcess_OLD] 
--DECLARE
@SystemName NVARCHAR(64), @ProcessName NVARCHAR(1024), @DaysBack INT, @MaxRunID_FromWinLosTable INT
AS 
BEGIN
IF ((@ProcessName NOT LIKE 'ManualProcess%') AND (@ProcessName NOT LIKE 'DailyProcess_Only_Revenue_Split%'))
BEGIN
--SET @SystemName = 'Brokasure'
--SET @ProcessName = 'DailyProcess.Update WC Stage All.update_stage_brokasure_uk_dim_policy_01'
--SET @DaysBack = -30

SET NOCOUNT ON;

DECLARE @CheckParameterResult BIT = 0, @SystemKey INT

EXEC [qv].[usp_GetSystemKeyFromName] @_SystemName = @SystemName, @_CallingProcName = 'usp_CalculateWinnersAndLosersPerProcess', @_CheckResult = @CheckParameterResult OUTPUT, @_SystemKey = @SystemKey OUTPUT
IF (@CheckParameterResult = 0)
BEGIN
	RETURN
END


IF OBJECT_ID('TempDb..#RunTimePerProcess_FullList') IS NOT NULL
    DROP TABLE #RunTimePerProcess_FullList;
CREATE TABLE #RunTimePerProcess_FullList
(
             [LogID]            BIGINT
           , [RunID]            BIGINT
           , [ProcessName]      NVARCHAR(256)
           , [ProcessStartTime] DATETIME
           , [ProcessEndTime]   DATETIME
           , [ProcessDuration]  TIME
           , [RecordsPerSecond] BIGINT
);
CREATE CLUSTERED INDEX [IX_LogID_RunID] ON #RunTimePerProcess_FullList
([LogID] ASC, [RunID] ASC
) 
       WITH(PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON);
DECLARE @KeyTable TABLE
(
                        SystemKey INT
                      , LastRunID INT
);
INSERT INTO @KeyTable
       SELECT DISTINCT 
              s.[dim_aon_system_key]
            , ISNULL(MAX(r.[RunID]), 0)
       FROM 
            [qv].[dim_aon_system] s
            JOIN [qv].[ETL_Stats_LastRunTaskList] r ON r.[SystemKey] = s.[dim_aon_system_key]
       WHERE s.[dim_aon_system_key] = @SystemKey
             --s.[systemname] = @SystemName
             AND r.[ProcessName] = @ProcessName
       GROUP BY 
                s.[dim_aon_system_key];
					
		-- ALL SYSTEMS ON AON_MI_DWH:
		-- //////////////////// @SystemName = 'Broaksure'   => SystemKey = 115
		-- //////////////////// @SystemName = 'Pure'		=> SystemKey = 110
		-- //////////////////// @SystemName = 'MGA'			=> SystemKey = 122

		IF ((SELECT COUNT(SystemKey) FROM @KeyTable WHERE SystemKey IN (115, 110, 122)) > 0)
		BEGIN
		; WITH 
		LastRunTaskList AS
		(
			SELECT		rt.[ProcessName],
						rt.[RunID]
			FROM		[qv].[ETL_Stats_LastRunTaskList] rt
			WHERE		rt.[RunID] = (SELECT LastRunID FROM @KeyTable)
						AND rt.[ChildTaskName] IS NOT NULL 
		)
					INSERT INTO #RunTimePerProcess_FullList([LogID], [RunID], [ProcessName], [ProcessStartTime], [ProcessEndTime], [ProcessDuration], [RecordsPerSecond]) 
					(				
						SELECT
										  lt.[LogID]
										, lt.[RunID]
										, lt.[ProcessName]						AS [ProcessName]
										, lt.[ProcessStartTime]					AS [ProcessStartTime]
										, lt.[ProcessEndTime]					AS [ProcessEndTime]
										, lt.[ProcessDuration]					AS [ProcessDuration]

										, CASE CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
										  WHEN 0 THEN NULL 
										  ELSE (COALESCE(lt.[InsertCount], 0)+COALESCE(lt.[UpdateCount], 0)+COALESCE(lt.[DeleteCount], 0))/CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
										  END									AS [RecordsPerSecond]
					
						FROM			[qv].[LogTable] lt WITH(NOLOCK)
						INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK) ON	s.[dim_aon_system_key] = lt.[SystemKey]
						INNER JOIN		LastRunTaskList lr ON lr.ProcessName = lt.ProcessName
						
						WHERE			s.[dim_aon_system_key] = @SystemKey
										--s.[systemname] = @SystemName
										AND lt.[ProcessName] = @ProcessName
										AND CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @DaysBack)
					)
		END
		
		-- ALL SYSTEMS ON ACIA_DWH:
		ELSE
		BEGIN
		; WITH 
		LastRunTaskList AS
		(
			SELECT		rt.[ProcessName]
			FROM		[qv].[ETL_Stats_LastRunTaskList] rt
			WHERE		rt.[RunID] = (SELECT LastRunID FROM @KeyTable)
						AND rt.[ChildTaskName] IS NOT NULL 
		)
					INSERT INTO #RunTimePerProcess_FullList([LogID], [RunID], [ProcessName], [ProcessStartTime], [ProcessEndTime], [ProcessDuration], [RecordsPerSecond]) 
					(				
						SELECT
										  lt.[LogID]
										, lt.[RunID]
										, lt.[ProcessName]						AS [ProcessName]
										, lt.[ProcessStartTime]					AS [ProcessStartTime]
										, lt.[ProcessEndTime]					AS [ProcessEndTime]
										, lt.[ProcessDuration]					AS [ProcessDuration]
										, CASE CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
										  WHEN 0 THEN NULL 
										  ELSE (COALESCE(lt.[InsertCount], 0)+COALESCE(lt.[UpdateCount], 0)+COALESCE(lt.[DeleteCount], 0))/CONVERT(BIGINT, DATEDIFF(ss, 0, lt.[ProcessDuration]))
										  END									AS [RecordsPerSecond]
					
						FROM			[qv].[LogTable_ACIA] lt WITH(NOLOCK)
						INNER JOIN		[qv].[dim_aon_system] s WITH(NOLOCK) ON	s.[dim_aon_system_key] = lt.[SystemKey]
						INNER JOIN		LastRunTaskList lr ON lr.ProcessName = lt.ProcessName
						
						WHERE			s.[dim_aon_system_key] = @SystemKey
										--s.[systemname] = @SystemName
										AND lt.[ProcessName] = @ProcessName
										AND CAST(lt.[ProcessStartTime] AS DATE) >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), @DaysBack)
					)
		END
		
		DECLARE @AvgUnadjusted TIME, @StDevInMinutes INT
		
		SELECT @AvgUnadjusted = CAST(DATEADD(MS, AVG(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessDuration]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)
		FROM #RunTimePerProcess_FullList
		--SELECT @AvgUnadjusted
		
		SELECT @StDevInMinutes = CAST(DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), CAST(DATEADD(MS, STDEV(CAST(DATEDIFF( MS, '00:00:00', CAST([ProcessDuration]  AS TIME)) AS BIGINT)), '00:00:00') AS TIME)) AS INT)
		FROM #RunTimePerProcess_FullList
		--SELECT @StDevInMinutes
		
		IF (@StDevInMinutes = 0)
			PRINT 'StdDev for '+@ProcessName+' = 0'
		ELSE
		BEGIN
		--DECLARE @SystemKey INT;
		--SELECT @SystemKey = SystemKey FROM @KeyTable
			SELECT DISTINCT
						@SystemKey																AS [SystemKey],
						fl.[RunID]																AS [RunID],
						fl.[LogID]																AS [LogID],
						GETDATE()																AS [TimeRecorded],
						@ProcessName															AS [TaskName],
						@DaysBack																AS [NumDaysBack],
						fl.[ProcessDuration]													AS [TaskDuration],
						@AvgUnadjusted															AS [AvgUnadjusted],
						@StDevInMinutes															AS [StDevInMinutes],
						DATEDIFF(MINUTE, CAST(fl.[ProcessDuration] AS TIME), @AvgUnadjusted)	AS [DiffFromStdDev],
						[RecordsPerSecond]														AS [RecordsPerSecond]						
			FROM 
						#RunTimePerProcess_FullList fl
			WHERE
						-- if parameter @MaxRunID_FromWinLosTable is supplied return only the results of newer (>) RunID's,  
						-- otherwise return all RunID's for that System (fl.[RunID] > 0):
						fl.[RunID] > COALESCE(@MaxRunID_FromWinLosTable, 0) AND
						
						-- return only the outlier results (outside of standard deviation):
						(
							DATEDIFF(MINUTE, CAST(fl.[ProcessDuration] AS TIME), @AvgUnadjusted) > @StDevInMinutes OR
							DATEDIFF(MINUTE, CAST(fl.[ProcessDuration] AS TIME), @AvgUnadjusted) < @StDevInMinutes * -1
						)
		END
		--SELECT @AvgAdjusted --AS [AdjustedAvgFinishTime]
END
END
GO

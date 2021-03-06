USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_Purge_ETL_StatsFromMidnight]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [qv].[usp_Purge_ETL_StatsFromMidnight] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Today DATETIME2, @YesterdayEOB DATETIME2
	SET @Today = CAST(GETDATE() AS DATE)
	SET @YesterdayEOB = DATEADD(SS, -1, DATEADD(s, 86400, DATEADD(DAY,-1, @Today)))
	--SELECT @YesterdayEOB
	
	DELETE FROM [DWHSupport_Audit].[qv].[ETL_Stats_AvgFinishTime_System]	WHERE TimeRecorded > @YesterdayEOB
	DELETE FROM [DWHSupport_Audit].[qv].[ETL_Stats_AvgFinishTime_Task]		WHERE TimeRecorded > @YesterdayEOB
	DELETE FROM [DWHSupport_Audit].[qv].[ETL_Stats_LastRunTaskList]			WHERE TimeRecorded > @YesterdayEOB
	DELETE FROM [DWHSupport_Audit].[qv].[ETL_Stats_WinnersAndLosers]		WHERE TimeRecorded > @YesterdayEOB

END
GO

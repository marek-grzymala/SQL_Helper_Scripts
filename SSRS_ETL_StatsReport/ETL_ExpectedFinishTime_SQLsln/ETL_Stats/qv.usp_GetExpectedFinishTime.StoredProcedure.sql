USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_GetExpectedFinishTime]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [qv].[usp_GetExpectedFinishTime]
@SystemName NVARCHAR(64) = NULL, @SystemKey INT = NULL
AS
BEGIN

SET NOCOUNT ON;
/*
DECLARE @ErMessage NVARCHAR(2048),
		@ErSeverity INT,
		@ErState INT

IF (@SystemName IS NULL AND @SystemKey IS NULL)
BEGIN
		SELECT
		   @ErMessage = 'You have to supply either @SystemName or @SystemKey - they can''t be both NULL!',
		   @ErSeverity = 15, --ERROR_SEVERITY(),
		   @ErState = ERROR_STATE()
		RAISERROR (@ErMessage, @ErSeverity, @ErState)
		RETURN
END

IF (@SystemName IS NOT NULL AND @SystemKey IS NOT NULL)
BEGIN
		SELECT
		   @ErMessage = 'You have to supply either @SystemName or @SystemKey - don''t supply both!',
		   @ErSeverity = 15, --ERROR_SEVERITY(),
		   @ErState = ERROR_STATE()
		RAISERROR (@ErMessage, @ErSeverity, @ErState)
		RETURN
END
*/

IF (@SystemName IS NOT NULL)
	BEGIN
		EXECUTE [qv].[usp_GetExpectedFinishTime_PerSystem] @SystemName = @SystemName
	END
ELSE IF (@SystemKey IS NOT NULL)
	BEGIN
		EXECUTE [qv].[usp_GetExpectedFinishTime_PerSystem] @SystemKey = @SystemKey
	END
ELSE
	BEGIN
		EXECUTE [qv].[usp_GetExpectedFinishTime_AllRunningSystems]
	END
END
GO

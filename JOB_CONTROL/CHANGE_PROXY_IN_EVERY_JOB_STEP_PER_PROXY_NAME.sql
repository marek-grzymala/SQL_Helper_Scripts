USE [msdb]
GO

SET NOCOUNT ON

DECLARE @OldProxyName NVARCHAR(256) = 'OldProxy'
DECLARE @NewProxyName NVARCHAR(256) = 'NewProxy'
DECLARE @NewProxyId INT
DECLARE @ChangedJobStepCounter INT = 0

DECLARE
	 @job_id NVARCHAR(100)
	,@JobName NVARCHAR(256)
    ,@step_id INT
    ,@JobStepName NVARCHAR(256)
    ,@PackageFolderPath NVARCHAR(MAX)
    ,@command NVARCHAR(MAX)
    ,@RowCount INT

SELECT @NewProxyId = SP.proxy_id FROM msdb.dbo.sysproxies SP WHERE SP.name = @NewProxyName

DROP TABLE IF EXISTS #OldJobSteps
CREATE TABLE [dbo].[#OldJobSteps] (
               [job_id] UNIQUEIDENTIFIER NOT NULL   
             , [JobName] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [step_id] INT NOT NULL   
             , [step_name] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [ProxyId] INT NOT NULL   
             , [ProxyName] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [PackageFolderPath] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL   
             , [command] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL  
             ) 

DROP TABLE IF EXISTS #NewJobSteps
CREATE TABLE [dbo].[#NewJobSteps] (
               [job_id] UNIQUEIDENTIFIER NOT NULL   
             , [JobName] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [step_id] INT NOT NULL   
             , [step_name] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [ProxyId] INT NOT NULL   
             , [ProxyName] SYSNAME COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL   
             , [PackageFolderPath] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL   
             , [command] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL  
             ) 

;WITH CTE1 AS (
    SELECT 
                 J.job_id
                ,[IsEnabled] = J.enabled
                ,[JobName] = J.name
                ,JS.step_id
                ,JS.step_name
                ,JS.command
                ,[ProxyId] = SP.proxy_id
                ,[ProxyName] = SP.name
                ,[StartIndex] = 
                 CASE 
                     WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%' OR JS.command LIKE '/ISSERVER%' THEN CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) --'
                     WHEN JS.command LIKE '/SERVER%' THEN CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) + 1
                     ELSE 0
                 END
                ,[EndIndex] = 
                 CASE 
                     WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%'  OR JS.command LIKE '/ISSERVER%' 
                         THEN  CHARINDEX('"',JS.command, CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1)) --'
                             - CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) - 1 --'
                     WHEN JS.command LIKE '/SERVER%' 
                         THEN  CHARINDEX('"',command, CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) + 1)
                             - CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) - 1
                     ELSE 0
                 END
    FROM         msdb.dbo.sysjobsteps JS 
    INNER JOIN   msdb.dbo.sysjobs J ON JS.job_id = J.job_id
    INNER JOIN   msdb.dbo.sysproxies SP ON SP.proxy_id = JS.proxy_id
)
INSERT INTO #OldJobSteps
(
    job_id,
    JobName,
    step_id,
    step_name,
    ProxyId,
    ProxyName,
    PackageFolderPath,
    command
)
SELECT 
              C1.job_id
            , C1.JobName
            , C1.step_id
            , C1.step_name
            , C1.ProxyId
            , C1.ProxyName
            , PackageFolderPath = 
              CASE 
                  WHEN C1.command LIKE '/DTS%' OR C1.command LIKE '/ISSERVER%' THEN SUBSTRING(C1.command, C1.StartIndex, C1.EndIndex)
                  WHEN C1.command LIKE '/SQL%' THEN '\MSDB' + SUBSTRING(C1.command, C1.StartIndex, C1.EndIndex)
                  WHEN C1.command LIKE '/SERVER%' THEN '\MSDB\' + SUBSTRING(C1.command, C1.StartIndex, C1.EndIndex)
                  ELSE NULL
              END
            , C1.command
FROM        CTE1 C1
WHERE       
            C1.[IsEnabled] = 1
AND         C1.ProxyName = @OldProxyName
ORDER BY    C1.job_id, C1.step_id

SELECT * FROM #OldJobSteps
WHERE       1 = 1
AND         ProxyName = @OldProxyName
ORDER BY    job_id, step_id

	WHILE EXISTS (SELECT * FROM #OldJobSteps)
	BEGIN

		SELECT TOP 1
			 @job_id            = job_id
			,@JobName           = JobName
            ,@step_id           = step_id
            ,@JobStepName       = step_name
            ,@PackageFolderPath = PackageFolderPath
            ,@command           = command

		FROM #OldJobSteps
------------------------------------------------------------------------------------------------------------------------------
-- DO THE ACTUAL STEP UPDATE:
------------------------------------------------------------------------------------------------------------------------------
		EXEC msdb.dbo.sp_update_jobstep
			@job_id = @job_id,
			@step_id = @step_id,
            @proxy_id = @NewProxyId
        SELECT @RowCount = @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
		PRINT 'Modified '+CAST(@RowCount AS NVARCHAR(10))+' step(s): ['+@JobStepName+'] of job: '+@JobName+', changed proxy id to: '+CAST(@NewProxyId AS NVARCHAR(10))
		SET @ChangedJobStepCounter = @ChangedJobStepCounter + 1
		
	INSERT INTO #NewJobSteps
	(
	    job_id,
	    JobName,
	    step_id,
	    step_name,
	    ProxyId,
	    ProxyName,
	    PackageFolderPath,
	    command
	)
	VALUES
	(   @job_id, -- job_id - uniqueidentifier
	    @JobName, -- JobName - sysname
	    @step_id,    -- step_id - int
	    @JobStepName, -- step_name - sysname
	    @NewProxyId,    -- ProxyId - int
	    @NewProxyName, -- ProxyName - sysname
	    @PackageFolderPath,  -- PackageFolderPath - nvarchar(max)
	    @command   -- command - nvarchar(max)
	    )
    DELETE #OldJobSteps WHERE @job_id = job_id AND step_id = @step_id
	END

PRINT 'Total number of jobs modified: '+CONVERT(NVARCHAR(10), @ChangedJobStepCounter)

SELECT DISTINCT C1.* FROM #NewJobSteps C1

INNER JOIN  msdb.dbo.sysjobsteps JS ON JS.job_id = C1.job_id
INNER JOIN  msdb.dbo.sysjobs J ON JS.job_id = J.job_id
INNER JOIN  msdb.dbo.sysproxies SP ON SP.proxy_id = JS.proxy_id

WHERE       1 = 1
AND         C1.ProxyId = @NewProxyId
ORDER BY    C1.job_id, C1.step_id

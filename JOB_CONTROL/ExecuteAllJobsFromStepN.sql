USE [msdb]
GO

DECLARE @InstanceName NVARCHAR(100) = @@servername, @JobStepName NVARCHAR(100) = 'JobStepNameToExecuteFrom'


BEGIN

	DECLARE
		 @_job_id NVARCHAR(100)
		,@command NVARCHAR(4000)
		,@system_name NVARCHAR(100)
		,@_job_name VARCHAR(100)
		,@dim_aon_systemkey NVARCHAR(30)
		,@environment NVARCHAR(100)

	IF OBJECT_ID('tempdb.dbo.#all_sysjobs') IS NOT NULL
		DROP TABLE #all_sysjobs

SELECT * INTO #all_sysjobs FROM msdb.dbo.sysjobs
where name like 'JobNamesToSelect%'

INSERT INTO #all_sysjobs SELECT * FROM msdb.dbo.sysjobs
where name like 'AdditionalJobNamesToSelect%'

	DELETE FROM #all_sysjobs WHERE name IN ('JobNameTExclude', 'AdditionalJObNameToExclude')
	DELETE FROM #all_sysjobs WHERE name LIKE '%AdditionalJobNameToExclude'
	DECLARE @counter INT = 0

	WHILE EXISTS (SELECT * FROM #all_sysjobs)
	BEGIN

		SELECT TOP 1
			 @_job_id        = job_id
			,@_job_name      = name
		FROM #all_sysjobs


		BEGIN
		DECLARE @_step_name NVARCHAR(256)
			SELECT
					@_step_name = S.step_name
			FROM msdb.dbo.sysjobs J
				INNER JOIN msdb.dbo.sysjobsteps S ON S.job_id = J.job_id
			WHERE 
				J.name = @_job_name AND S.step_name = @JobStepName
			IF (@_step_name IS NOT NULL) AND (@_job_name IS NOT NULL) AND (@_job_id IS NOT NULL)
			BEGIN
				EXEC sp_start_job @job_id = @_job_id, @step_name = @_step_name
				PRINT 'Executed step: '+@_step_name+' of job: '+@_job_name+' job id: '+@_job_id
			END
			SET @_step_name = NULL
			SET @counter = @counter + 1
		END

	DELETE #all_sysjobs WHERE @_job_id = job_id
	END
PRINT 'Total number of jobs executed: '+CONVERT(NVARCHAR(10), @counter)
END



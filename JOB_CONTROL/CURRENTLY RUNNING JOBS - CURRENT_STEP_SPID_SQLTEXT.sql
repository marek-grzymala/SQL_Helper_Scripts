declare @xp_results TABLE (
    job_id                UNIQUEIDENTIFIER NOT NULL,
    last_run_date         INT              NOT NULL,
    last_run_time         INT              NOT NULL,
    next_run_date         INT              NOT NULL,
    next_run_time         INT              NOT NULL,
    next_run_schedule_id  INT              NOT NULL,
    requested_to_run      INT              NOT NULL, -- BOOL
    request_source        INT              NOT NULL,
    request_source_id     sysname          COLLATE database_default NULL,
    running               INT              NOT NULL, -- BOOL
    current_step          INT              NOT NULL,
    current_retry_attempt INT              NOT NULL,
    job_state             INT              NOT NULL);

INSERT INTO @xp_results EXECUTE master.dbo.xp_sqlagent_enum_jobs 1, 'sa'--, @job_id

SELECT 
                sj.name AS [JobName],
                xpr.current_step,
                CASE xpr.job_state 
                                    WHEN 1 THEN 'Executing: ' + cast(sjs.step_id AS NVARCHAR(2)) + ' (' + sjs.step_name + ')'
                                    WHEN 2  THEN 'Waiting for thread'
                                    WHEN 3  THEN 'Between retries'
                                    WHEN 4  THEN 'Idle'
                                    WHEN 5  THEN 'Suspended'
                                    WHEN 7  THEN 'Performing completion actions'
                END AS [status]
FROM            @xp_results xpr
INNER JOIN      msdb..sysjobs sj on xpr.job_id = sj.job_id
LEFT OUTER JOIN msdb.dbo.sysjobsteps sjs ON ((xpr.job_id = sjs.job_id) AND (xpr.current_step = sjs.step_id)),
                msdb.dbo.sysjobs_view sjv
WHERE           (sjv.job_id = xpr.job_id) AND xpr.job_state IS NOT NULL AND xpr.job_state <> 4
GO


;WITH JobDetails
AS (
    SELECT  DISTINCT 
                     x.spid
                    ,x.cmd
                    ,x.nt_username
                    ,x.loginame
                    ,x.login_time
                    ,x.sql_handle
                    ,x.status
                    ,x.last_batch
                    ,x.lastwaittype
                    ,x.waittime
                    ,Job_Id = left(intr1, charindex(':', intr1) - 1)
                    ,Step = substring(intr1, charindex(':', intr1) + 1, charindex(')', intr1) - charindex(':', intr1) - 1)
                    ,SessionId = spid
    FROM            master.dbo.sysprocesses x
    CROSS APPLY (
                    SELECT replace(x.program_name, 'SQLAgent - TSQL JobStep (Job ', '')
                )   cs(intr1)
    WHERE       spid > 50
    /*
               IN (
                    SELECT
                    	        c.session_id
                    FROM        sys.dm_exec_connections AS c
                    INNER JOIN  sys.dm_exec_sessions s ON s.session_id = c.session_id
                    WHERE       1 = 1 
                    AND         c.auth_scheme IN ('NTLM')
                  )
      */
      AND x.program_name LIKE 'SQLAgent - TSQL JobStep (Job %'
    )
SELECT 
            j.name AS [JobName]
            ,j.description
            ,jd.spid

            ,jd.loginame
            ,jd.login_time
            ,t.text
            ,jd.cmd
            ,jd.status
            ,jd.last_batch
            ,jd.lastwaittype
            ,jd.waittime

FROM        msdb.dbo.sysjobs j
INNER JOIN  JobDetails jd ON jd.Job_Id = CONVERT(VARCHAR(MAX), CONVERT(BINARY (16), j.job_id), 1)
CROSS APPLY sys.dm_exec_sql_text(jd.sql_handle) t
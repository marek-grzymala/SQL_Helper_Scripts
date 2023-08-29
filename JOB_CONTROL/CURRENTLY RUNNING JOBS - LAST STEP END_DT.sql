DROP TABLE IF EXISTS #enum_jobs

CREATE TABLE #enum_jobs (
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
INSERT INTO #enum_jobs EXECUTE master.dbo.xp_sqlagent_enum_jobs 1, 'sa'--, @job_id

DROP TABLE IF EXISTS #job_hist
CREATE TABLE #job_hist
(
    [job_id] UNIQUEIDENTIFIER   NOT NULL,
    [JobName] NVARCHAR(128)     NOT NULL,
    [step_id] INT               NOT NULL,
    [step_name] NVARCHAR(128)   NOT NULL,
    [RunDateTime] DATETIME      NOT NULL,
    [End_DateTime] DATETIME     NOT NULL
);                              

; WITH cte AS (
SELECT   
          sj.job_id
         ,sj.name AS [JobName]
         ,jh.step_id
         ,jh.step_name
         ,[RunDateTime] = msdb.dbo.agent_datetime(jh.run_date, jh.run_time)
         , DATEADD(SECOND, (jh.run_duration / 10000 * 3600 + (jh.run_duration % 10000 / 100 * 60) + jh.run_duration % 100), msdb.dbo.agent_datetime(jh.run_date, jh.run_time)) AS End_DateTime
         , RANK() OVER (PARTITION BY sj.job_id, jh.step_id ORDER BY msdb.dbo.agent_datetime(jh.run_date, jh.run_time) DESC) AS [DateRunRank]
FROM     msdb.dbo.sysjobs sj
JOIN     msdb.dbo.sysjobhistory jh ON sj.job_id = jh.job_id

WHERE    1 = 1
AND      msdb.dbo.agent_datetime(jh.run_date, jh.run_time) > DATEADD(HOUR, -48, GETDATE())
AND      jh.step_id <> 0 -- we do not want (Job Outcome)
)
INSERT INTO #job_hist
(
    job_id,
    JobName,
    step_id,
    step_name,
    RunDateTime,
    End_DateTime
)
SELECT 
            cte.job_id,
            cte.JobName,
            cte.step_id,
            cte.step_name,
            cte.RunDateTime,
            cte.End_DateTime
FROM 
            cte
WHERE       cte.DateRunRank = 1
ORDER BY    cte.job_id, cte.step_id DESC 

--SELECT * FROM #job_hist WHERE job_id IN ('5B1F335B-2799-4204-9F4F-2C05CA455974', 'BBE5DB2C-18BD-49E7-8698-09497BAF5443', 'D6CD306F-19F2-4B3C-90BE-1FA3789D47B7', '5D37F37A-BD9D-46F3-A5EA-1F9EE932D476')

/*------------------------------------------------------------------------------------------------------------------------------*/
; WITH LastStepEndDt AS (
SELECT 
            job_id,
            MAX(End_DateTime) AS [StepEndDt]
FROM        #job_hist
GROUP BY    job_id
)
SELECT          DISTINCT
                sj.job_id
                ,sj.[name] AS [JobName]
                ,enj.current_step
                ,CASE enj.job_state 
                                    WHEN 1  THEN 'Executing: ' + CAST(sjs.step_id AS NVARCHAR(2)) + ' (' + sjs.step_name + ')'
                                    WHEN 2  THEN 'Waiting for thread'
                                    WHEN 3  THEN 'Between retries'
                                    WHEN 4  THEN 'Idle'
                                    WHEN 5  THEN 'Suspended'
                                    WHEN 7  THEN 'Performing completion actions'
                 END AS [status]
                --,cte.step_id            AS [LastStepIdRun]
                --,[RunningSince] = jh.[RunDateTime]
                ,CASE enj.current_step
                        WHEN 1 THEN NULL
                        ELSE lse.StepEndDt
                END AS [LastStepEndDt]

FROM            #enum_jobs              AS enj
INNER JOIN      msdb.dbo.sysjobs        AS sj     ON enj.job_id = sj.job_id
LEFT OUTER JOIN msdb.dbo.sysjobsteps    AS sjs    ON ((enj.job_id = sjs.job_id) AND (enj.current_step = sjs.step_id))
CROSS APPLY     msdb.dbo.sysjobs_view   AS sjv
CROSS APPLY     LastStepEndDt           AS lse

CROSS APPLY    msdb.dbo.sysjobactivity AS sja 

WHERE           (sjv.job_id = enj.job_id) --AND (sj.job_id = jh.job_id AND sjs.step_id = jh.step_id)
AND             enj.job_state = 1 -- we only want to see executing jobs!
AND             lse.job_id = sj.job_id
AND             sj.job_id = sja.job_id


--AND                 msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time) > GETDATE() - 1

ORDER BY        sj.[name] DESC 


--SELECT * FROM #job_hist WHERE job_id IN ('5B1F335B-2799-4204-9F4F-2C05CA455974', 'BBE5DB2C-18BD-49E7-8698-09497BAF5443', 'D6CD306F-19F2-4B3C-90BE-1FA3789D47B7', '5D37F37A-BD9D-46F3-A5EA-1F9EE932D476')
USE msdb;
GO

SELECT j.name [JobName],
       
       h.step_name AS [StepName],
       CONVERT(CHAR(10), CAST(STR(h.run_date, 8, 0) AS DATETIME), 111) AS [RunDate],
       STUFF(STUFF(RIGHT('000000' + CAST(h.run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':') AS [RunTime],
       STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(h.run_duration as varchar(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS [StepDuration (DD:HH:MM:SS)],
       CASE h.run_status
           WHEN 0 THEN
               'Failed'
           WHEN 1 THEN
               'Succeded'
           WHEN 2 THEN
               'Retry'
           WHEN 3 THEN
               'Cancelled'
           WHEN 4 THEN
               'In Progress'
       END AS ExecutionStatus,
       h.message MessageGenerated
FROM sysjobhistory h
    INNER JOIN sysjobs j
        ON j.job_id = h.job_id
WHERE j.name = 'JobName'
ORDER BY j.name,
         h.run_date DESC,
         h.run_time DESC;
GO
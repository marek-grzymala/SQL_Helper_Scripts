USE [msdb];
GO

WITH jobs
AS (SELECT c.schedule_id,
           a.name AS [JOB NAME],
           a.[description] AS [JOB DESCRIPTION],
           c.[name] AS [SCHEDULE NAME],
           a.enabled,
           CASE c.freq_type -- Daily, weekly, Monthly
               WHEN 1 THEN
                   'Once'
               WHEN 4 THEN
                   'Daily'
               WHEN 8 THEN
                   'Wk ' -- For weekly, add in the days of the week
                   + CASE freq_interval & 2
                         WHEN 2 THEN
                             'M'
                         ELSE
                             ''
                     END -- Monday
                   + CASE freq_interval & 4
                         WHEN 4 THEN
                             'Tu'
                         ELSE
                             ''
                     END -- Tuesday
                   + CASE freq_interval & 8
                         WHEN 8 THEN
                             'W'
                         ELSE
                             ''
                     END -- etc
                   + CASE freq_interval & 16
                         WHEN 16 THEN
                             'Th'
                         ELSE
                             ''
                     END + CASE freq_interval & 32
                               WHEN 32 THEN
                                   'F'
                               ELSE
                                   ''
                           END + CASE freq_interval & 64
                                     WHEN 64 THEN
                                         'Sa'
                                     ELSE
                                         ''
                                 END + CASE freq_interval & 1
                                           WHEN 1 THEN
                                               'Su'
                                           ELSE
                                               ''
                                       END
               WHEN 16 THEN
                   'Mthly on day ' + CONVERT(VARCHAR(2), freq_interval) -- Monthly on a particular day
               WHEN 32 THEN
                   'Mthly ' -- The most complicated one, "every third Friday of the month" for example
                   + CASE c.freq_relative_interval
                         WHEN 1 THEN
                             'Every First '
                         WHEN 2 THEN
                             'Every Second '
                         WHEN 4 THEN
                             'Every Third '
                         WHEN 8 THEN
                             'Every Fourth '
                         WHEN 16 THEN
                             'Every Last '
                     END + CASE c.freq_interval
                               WHEN 1 THEN
                                   'Sunday'
                               WHEN 2 THEN
                                   'Monday'
                               WHEN 3 THEN
                                   'Tuesday'
                               WHEN 4 THEN
                                   'Wednesday'
                               WHEN 5 THEN
                                   'Thursday'
                               WHEN 6 THEN
                                   'Friday'
                               WHEN 7 THEN
                                   'Saturday'
                               WHEN 8 THEN
                                   'Day'
                               WHEN 9 THEN
                                   'Week day'
                               WHEN 10 THEN
                                   'Weekend day'
                           END
               WHEN 64 THEN
                   'Startup'                                            -- When SQL Server starts
               WHEN 128 THEN
                   'Idle'                                               -- Whenever SQL Server gets bored
               ELSE
                   'Err'                                                -- This should never happen
           END AS schedule,
           CASE c.freq_subday_type -- FOr when a job funs every few seconds, minutes or hours
               WHEN 1 THEN
                   'Runs once at:'
               WHEN 2 THEN
                   'every ' + CONVERT(VARCHAR(3), freq_subday_interval) + ' seconds'
               WHEN 4 THEN
                   'every ' + CONVERT(VARCHAR(3), freq_subday_interval) + ' minutes'
               WHEN 8 THEN
                   'every ' + CONVERT(VARCHAR(3), freq_subday_interval) + ' hours'
           END AS frequency,
           SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_start_time), 6), 1, 2) + ':'
           + SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_start_time), 6), 3, 2) + ':'
           + SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_start_time), 6), 5, 2) AS start_at,
           CASE c.freq_subday_type
               WHEN 1 THEN
                   NULL -- Ignore the end time if not a recurring job
               ELSE
                   SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_end_time), 6), 1, 2) + ':'
                   + SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_end_time), 6), 3, 2)
                   + ':'
                   + SUBSTRING(RIGHT(STUFF(' ', 1, 1, '000000') + CONVERT(VARCHAR(6), c.active_end_time), 6), 5, 2)
           END AS end_at
    FROM msdb.dbo.sysjobs a
        INNER JOIN
        --select * from
        msdb.dbo.sysjobschedules b
            ON a.job_id = b.job_id
        INNER JOIN
        --select * from
        msdb.dbo.sysschedules c
            ON b.schedule_id = c.schedule_id
    WHERE c.enabled = 1)
SELECT *
FROM jobs
WHERE 1 = 1
      AND         [jobs].[JOB DESCRIPTION] <> 'This job is owned by a report server process. Modifying this job could result in database incompatibilities. Use Report Manager or Management Studio to update this job.'
      AND jobs.enabled = 1
ORDER BY frequency; --[SCHEDULE NAME] DESC --schedule_id --name desc --frequency
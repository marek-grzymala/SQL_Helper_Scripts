SELECT 
                    --CONVERT(nvarchar(128), SERVERPROPERTY('Servername')) AS Server,
                    --msdb.dbo.sysjobs.job_id,
                    msdb.dbo.sysjobs.name,
                    msdb.dbo.sysjobs.enabled AS Job_Enabled,
                    msdb.dbo.sysjobs.description,
                    --msdb.dbo.sysjobs.notify_level_eventlog,
                    --msdb.dbo.sysjobs.notify_level_email,
                    --msdb.dbo.sysjobs.notify_level_netsend,
                    --msdb.dbo.sysjobs.notify_level_page,
                    --msdb.dbo.sysjobs.notify_email_operator_id,
                    --msdb.dbo.sysjobs.date_created,
                    --msdb.dbo.syscategories.name AS Category_Name,
                    msdb.dbo.sysjobschedules.next_run_date,
                    msdb.dbo.sysjobschedules.next_run_time,
                    msdb.dbo.sysjobservers.last_run_outcome,
                    msdb.dbo.sysjobservers.last_outcome_message,
                    msdb.dbo.sysjobservers.last_run_date,
                    msdb.dbo.sysjobservers.last_run_time,
                    msdb.dbo.sysjobservers.last_run_duration,
                    --msdb.dbo.sysoperators.name AS Notify_Operator,
                    --msdb.dbo.sysoperators.email_address,
                    msdb.dbo.sysjobs.date_modified,
                    --msdb.dbo.sysschedules.name AS Schedule_Name,
                    --msdb.dbo.sysschedules.enabled,
                    --msdb.dbo.sysschedules.freq_type,
                    --msdb.dbo.sysschedules.freq_interval,
                    --msdb.dbo.sysschedules.freq_subday_interval,
                    --msdb.dbo.sysschedules.freq_subday_type,
                    --msdb.dbo.sysschedules.freq_relative_interval,
                    --msdb.dbo.sysschedules.freq_recurrence_factor,
                    --msdb.dbo.sysschedules.active_start_date,
                    --msdb.dbo.sysschedules.active_end_date,
                    --msdb.dbo.sysschedules.active_start_time,
                    --msdb.dbo.sysschedules.active_end_time,
                    --msdb.dbo.sysschedules.date_created AS Date_Sched_Created,
                    --msdb.dbo.sysschedules.date_modified AS Date_Sched_Modified,
                    --msdb.dbo.sysschedules.version_number,
                    msdb.dbo.sysjobs.version_number AS Job_Version
FROM                msdb.dbo.sysjobs
INNER JOIN          msdb.dbo.syscategories ON msdb.dbo.sysjobs.category_id = msdb.dbo.syscategories.category_id
LEFT OUTER JOIN     msdb.dbo.sysoperators  ON msdb.dbo.sysjobs.notify_page_operator_id = msdb.dbo.sysoperators.id
LEFT OUTER JOIN     msdb.dbo.sysjobservers ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobservers.job_id
LEFT OUTER JOIN     msdb.dbo.sysjobschedules ON msdb.dbo.sysjobschedules.job_id = msdb.dbo.sysjobs.job_id
LEFT OUTER JOIN     msdb.dbo.sysschedules ON msdb.dbo.sysjobschedules.schedule_id = msdb.dbo.sysschedules.schedule_id
WHERE               msdb.dbo.sysjobs.enabled = 1
--AND msdb.dbo.sysjobservers.last_run_outcome = 0

ORDER BY last_run_date DESC, last_run_time DESC 
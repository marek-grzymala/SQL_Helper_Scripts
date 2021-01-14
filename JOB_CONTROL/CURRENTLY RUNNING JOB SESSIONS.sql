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
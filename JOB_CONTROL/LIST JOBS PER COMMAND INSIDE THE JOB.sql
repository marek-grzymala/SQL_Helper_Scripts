--DECLARE @JobName NVARCHAR(256) = 'YourJobName%'
--DECLARE @ProxyName NVARCHAR(256) = 'YourProxyName'
DECLARE @CommandContents NVARCHAR(256) = '%command_inside_your_job%'


;WITH CTE1 AS (
    SELECT 
            J.job_id
        ,   [IsEnabled] = J.enabled
        ,   [JobName] = J.name
        ,   JS.step_id
        ,   JS.step_name
        ,   JS.command
        ,   [ProxyName] = SP.name
        ,   [StartIndex] = 
            CASE 
                WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%' OR JS.command LIKE '/ISSERVER%' THEN CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) --'
                WHEN JS.command LIKE '/SERVER%' THEN CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) + 1
                ELSE 0
            END
        ,   [EndIndex] = 
            CASE 
                WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%'  OR JS.command LIKE '/ISSERVER%' 
                    THEN  CHARINDEX('"',JS.command, CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1)) --'
                        - CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) - 1 --'
                WHEN JS.command LIKE '/SERVER%' 
                    THEN  CHARINDEX('"',command, CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) + 1)
                        - CHARINDEX('"', JS.Command, CHARINDEX(' ',command, CHARINDEX(' ',command) + 1) + 1) - 1
                ELSE 0
            END
    FROM msdb.dbo.sysjobsteps JS 
    INNER JOIN msdb.dbo.sysjobs J ON JS.job_id = J.job_id
    INNER JOIN msdb.dbo.sysproxies SP ON SP.proxy_id = JS.proxy_id
    
    --WHERE JS.subsystem = 'SSIS'
)    
SELECT 
            -- C1.job_id
              C1.JobName
            , C1.step_id
            , C1.step_name
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
WHERE       1 = 1
--AND         C1.[IsEnabled] = 1
--AND         C1.JobName LIKE @JobName AND C1.ProxyName = @ProxyName -- IS NOT NULL
AND         C1.command LIKE @CommandContents
ORDER BY    C1.job_id, C1.step_id
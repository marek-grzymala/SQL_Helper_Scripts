USE SSISDB
GO

DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'  --replace with the package name
DECLARE @DateSince DATETIME = DATEADD(DAY, -90, GETDATE())

SELECT         CAST(DATEADD(HOUR, DATEDIFF(HOUR, 0, ei.start_time), 0) AS TIME(0)) AS [StartTimeAfter (hh:mm:ss)],
               AVG(DATEDIFF(MINUTE, ei.start_time, ei.end_time)) AS [Avg. exec. time (minutes)]
FROM           [SSISDB].internal.execution_info ei WITH (NOLOCK)
LEFT JOIN      [SSISDB].catalog.execution_property_override_values ov WITH (NOLOCK)  ON ov.execution_id = ei.execution_id
WHERE
               ei.package_name =   @PackageName AND    
               ei.start_time   >=  @DateSince

GROUP BY       --DATEPART(HOUR, ei.start_time)
               CAST(DATEADD(HOUR, DATEDIFF(HOUR, 0, ei.start_time), 0) AS TIME(0))
ORDER BY        [StartTimeAfter (hh:mm:ss)]


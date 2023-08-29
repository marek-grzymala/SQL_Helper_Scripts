USE SSISDB
GO

DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'  --replace the package name
DECLARE @DateSince DATETIME = DATEADD(DAY, -14, GETDATE())

SELECT
    ei.execution_id,
    --ei.folder_name,
    ei.project_name,
    ei.package_name,
    CAST(ei.start_time AS DATETIME2(0))             AS [StartTime],
    CAST(ei.end_time AS DATETIME2(0))               AS [EndTime],
    CASE ei.status 
          WHEN 1 THEN 'Created'
          WHEN 2 THEN 'Running'
          WHEN 3 THEN 'Cancelled'
          WHEN 4 THEN 'Failed'
          WHEN 5 THEN 'About to run'
          WHEN 6 THEN 'Ended unexpectedly'
          WHEN 7 THEN 'Success'
          WHEN 8 THEN 'Stopping'
          WHEN 9 THEN 'Completed'
          ELSE 'Unknown'
    END AS [Status],
    CASE ei.status
          WHEN 2 THEN DATEDIFF(MINUTE, CAST(ei.start_time AS DATETIME2(0)), GETDATE())
          --WHEN 7 THEN DATEDIFF(MINUTE, ei.start_time, ei.end_time)
          --ELSE NULL
          ELSE DATEDIFF(MINUTE, ei.start_time, ei.end_time)
    END AS [minutes duration (so far if still running)],
    --ei.environment_folder_name,
    ei.environment_name,
    ei.executed_as_name,
    ov.property_path,
    ov.property_value
    --ei.use32bitruntime,
    --ei.operation_type
    --CAST(ei.created_time AS DATETIME2(0))             AS [CreatedTime],
    --ei.object_type

FROM           [SSISDB].internal.execution_info ei WITH (NOLOCK)
LEFT JOIN      [SSISDB].catalog.execution_property_override_values ov WITH (NOLOCK)  ON ov.execution_id = ei.execution_id

WHERE
        ei.package_name = @PackageName AND
        /*
        IN (
                , 'Package1.dtsx'
                , 'Package2.dtsx'
        ) AND 
        */
        ei.start_time >= @DateSince

ORDER BY ei.start_time DESC

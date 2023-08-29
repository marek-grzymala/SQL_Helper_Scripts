USE SSISDB
GO

DECLARE @UserName NVARCHAR(256) = 'DOMAIN\UserName'
DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'
DECLARE @DateSince DATE = GETDATE() - 7

SELECT
    ei.execution_id,
    ei.folder_name,
    ei.project_name,
    ei.package_name,
    ei.reference_id,
    ei.reference_type,
    ei.environment_folder_name,
    ei.environment_name,
    CAST(ei.start_time AS datetime) AS start_time,
    DATEDIFF(MINUTE, ei.start_time, ei.end_time) AS [execution_time (min)],
    ei.executed_as_name,
    ei.use32bitruntime,
    ei.operation_type,
    ei.created_time,
    ei.object_type



FROM SSISDB.internal.execution_info ei
WHERE
        --ei.executed_as_name = @UserName AND
        ei.package_name = @PackageName AND
        ei.start_time >= @DateSince AND
        ei.status = 4

-- status:
-- 4 = FAILED
-- 2 = RUNNING
-- 3 = CANCELLED
-- 5 = ABOUT TO BE RUN

ORDER BY ei.start_time DESC
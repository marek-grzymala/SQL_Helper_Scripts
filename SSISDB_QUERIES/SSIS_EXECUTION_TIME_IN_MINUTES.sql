
DECLARE @ExecMin BIGINT

SELECT folder_name, project_name, package_name,

CAST(start_time AS datetime) AS start_time,

DATEDIFF(MINUTE, start_time, end_time) AS 'execution_time[min]'

FROM SSISDB.internal.execution_info

ORDER BY 5 DESC, start_time DESC
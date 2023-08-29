SELECT TOP 200 
	b.package_name, a.* 
FROM    
[SSISDB].[internal].[operation_messages] a
LEFT JOIN [SSISDB].[catalog].[executions] b on a.operation_id = b.[execution_id]

WHERE a.[message_time] > DATEADD(HH, -24, GETDATE()) 
		--AND a.[message] LIKE '%buffer manager%'

ORDER BY a.[message_time] DESC
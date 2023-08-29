USE [tempdb]
GO


SELECT * INTO #temp FROM
(
	SELECT 
		DB_NAME(mf.database_id) AS [database_name]
		, mf.name AS [logical_file_name]
		, CONVERT (DECIMAL (20,2) , (CONVERT(DECIMAL, size)/128)) [file_size_MB]
		, CASE mf.is_percent_growth
			WHEN 1 THEN 'Yes'
			ELSE 'No'
			END AS [is_percent_growth]
		, CASE mf.is_percent_growth
			WHEN 1 THEN CONVERT(VARCHAR, mf.growth) + '%'
			WHEN 0 THEN CONVERT(VARCHAR, mf.growth/128) + ' MB'
		  END AS [growth_in_increment_of]
		
		, CASE mf.is_percent_growth
				WHEN 1 THEN
				CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, size)*growth)/100)*8)/1024)
				WHEN 0 THEN
				CONVERT(DECIMAL(20,2), (CONVERT(DECIMAL, growth)/128))
			END AS [current_auto_growth_size_MB]

		, CASE mf.is_percent_growth
				WHEN 1 THEN 
					CASE 
						--WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>256 THEN 256
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>128 THEN 256
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>64 THEN 128
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>32 THEN 64
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>16 THEN 32
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>8 THEN 16
						WHEN (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)>4 THEN 8
						ELSE (CEILING(CONVERT(DECIMAL(20,2), (((CONVERT(DECIMAL, mf.size)*mf.growth)/100)*8)/1024)/2.0)*2)
					END
                WHEN 0 THEN 0
		END AS [new_suggested_auto_growth_size_MB]

		, CASE mf.max_size
			WHEN 0 THEN 'No growth is allowed'
			WHEN -1 THEN 'File will grow until the disk is full'
			ELSE CONVERT(VARCHAR, mf.max_size)
			END AS [max_size]
		, [physical_name]

	FROM sys.master_files mf
    WHERE DB_NAME(mf.database_id) IN ('TempDb')
) AS list

SELECT * FROM #temp ORDER BY [current_auto_growth_size_MB] DESC--database_name

SELECT  'ALTER DATABASE ['+ [database_name] +'] MODIFY FILE (NAME = ['+[logical_file_name]+'], FILEGROWTH = '+CONVERT(NVARCHAR, ISNULL([new_suggested_auto_growth_size_MB], 0))+'MB)' 
FROM     #temp 
WHERE    [new_suggested_auto_growth_size_MB] IS NOT NULL
ORDER BY [new_suggested_auto_growth_size_MB] DESC

TRUNCATE TABLE #temp
DROP TABLE #temp


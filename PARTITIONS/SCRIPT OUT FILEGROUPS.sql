USE [PartitionTesting]
GO

SELECT 
                    sdf.file_id,
                    sdf.data_space_id,
                    'ALTER DATABASE '+DB_NAME()+' REMOVE FILEGROUP ', --ADD
                    '['+fg.name+']' AS [FileGroupName],
                    sdf.physical_name,
                    sdf.type_desc,
                    sdf.size,
                    sdf.max_size,
                    sdf.growth
 
FROM                sys.database_files sdf
RIGHT OUTER JOIN    sys.filegroups fg ON sdf.data_space_id = fg.data_space_id
WHERE               sdf.physical_name IS NULL

ORDER BY [FileGroupName]
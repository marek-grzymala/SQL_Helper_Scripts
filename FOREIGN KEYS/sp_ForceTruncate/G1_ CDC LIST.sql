IF EXISTS (
			SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] 
			WHERE [TABLE_SCHEMA] = 'cdc' AND [TABLE_NAME] = 'change_tables'
		  )

SELECT
       [capture_instance]	   
      ,[role_name]
      ,[filegroup_name]
FROM   [cdc].[change_tables]
--WHERE [source_object_id]

EXECUTE sys.sp_cdc_disable_table
@source_schema			= N'dbo',
@source_name			= N'WorkItemTransaction',
@capture_instance		= N'dbo_WorkItemTransaction';
GO

EXECUTE sys.sp_cdc_enable_table
@source_schema = N'dbo',
@source_name = N'WorkItemTransaction',
@role_name			= 'public',
@filegroup_name = 'DATA10'
GO
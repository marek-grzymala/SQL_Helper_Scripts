USE SSISDB;
GO

DECLARE @old_package_name VARCHAR(MAX) = 'ExistingPackage.dtsx',
        @new_package_name VARCHAR(MAX) = 'NewPackage.dtsx';

SELECT  DISTINCT
        'EXEC SSISDB.catalog.set_object_parameter_value @object_type = 30, @folder_name = N''' + fld.name
        + ''', @project_name = N''' + prj.name + ''', @parameter_name = N''' + prm.parameter_name
        + ''', @parameter_value = ''' + prm.referenced_variable_name + ''', @object_name = N''' + @new_package_name
        + ''', @value_type = ''R'''
FROM    SSISDB.internal.object_parameters prm
JOIN    SSISDB.internal.projects prj ON prj.project_id = prm.project_id
JOIN    SSISDB.internal.folders fld ON fld.folder_id = prj.folder_id
WHERE   prm.object_name = @old_package_name
AND     prm.value_type = 'R';
GO


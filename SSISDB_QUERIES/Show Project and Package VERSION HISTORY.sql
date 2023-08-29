USE SSISDB
GO
--Check full version history of installed SSIS packages
--NB only works for project deployment model

DECLARE @ProjectName NVARCHAR(256) = 'ProjectName'
DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'

SELECT       
             fd.name                                        AS [Folder Name]
            ,pj.name                                        AS [Project Name]
            ,pk.name                                        AS [Package Name]
            --,pj.object_version_lsn  AS [ProjectVersion]
            ,cp.package_format_version                      AS [PackageVersion]
            ,CAST(ov.created_time AS DATETIME2(0))          AS [Version Installed On]
            ,pk.project_version_lsn                         AS [Project LSN]
            ,pk.package_id                                  AS [Package Version]
            ,pk.version_build                               AS [Package Version Build]
            ,IIF(ov.object_version_lsn = pj.object_version_lsn, 'Yes', 'No') 
                                                            AS [Latest Version?]
            ,ov.created_by                                  AS [Version Created By]

FROM        internal.packages           pk
LEFT  JOIN  catalog.packages            cp                  ON cp.package_id = pk.package_id
INNER JOIN  internal.projects           pj                  ON pj.project_id = pk.project_id
INNER JOIN  internal.object_versions    ov                  ON ov.object_id = pj.project_id AND ov.object_version_lsn = pk.project_version_lsn
INNER JOIN  internal.folders            fd                  ON fd.folder_id = pj.folder_id

WHERE   pj.name = @ProjectName
AND     pk.name = @PackageName

ORDER BY 
         pj.name
        ,ov.created_time DESC
        ,pk.name
        ,pk.project_version_lsn DESC
        ,pk.version_build DESC


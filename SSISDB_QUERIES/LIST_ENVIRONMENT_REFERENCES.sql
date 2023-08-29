USE [SSISDB]
GO

SELECT  
	PackagePathName = FORMATMESSAGE('\SSISDB\%s\%s\%s\', F2.name, PJ.name, PK.name),
    EnvironnmentPathName = FORMATMESSAGE('\SSISDB\%s\%s', F.name, E.name),
    EnvironmentReferenceID = ER.reference_id,
    ProjectFolder = F.name,
    Project = PJ.name,
    Package = PK.name,
    EnvironmentFolder = F2.name,
    Environment = E.name
FROM    catalog.folders AS F
    INNER JOIN catalog.environments AS E ON E.folder_id = F.folder_id
    INNER JOIN catalog.environment_references AS ER ON (ER.reference_type = 'A'
            AND ER.environment_folder_name = F.name
            AND ER.environment_name = E.name)
        OR (ER.reference_type = 'R'
            AND ER.environment_name = E.name)
    INNER JOIN catalog.projects AS PJ ON PJ.project_id = ER.project_id AND PJ.folder_id = F.folder_id
    INNER JOIN catalog.packages AS PK ON PK.project_id = PJ.project_id
    INNER JOIN catalog.folders AS F2 ON F2.folder_id = PJ.folder_id

ORDER BY 3 DESC
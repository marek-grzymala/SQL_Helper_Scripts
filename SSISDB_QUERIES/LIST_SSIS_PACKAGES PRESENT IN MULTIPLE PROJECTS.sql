USE [SSISDB]
GO


/*
SELECT
            name,
            COUNT(DISTINCT package_id) AS [NumOfPackageIds]

FROM        catalog.packages
GROUP BY    name
HAVING      COUNT(DISTINCT package_id) > 1
ORDER BY    [NumOfPackageIds] DESC
GO
*/

; WITH MultiprojectPackageNames AS (
SELECT
            name,
            COUNT(DISTINCT package_id) AS [NumOfSameNamePackages]

FROM        catalog.packages
GROUP BY    name
HAVING      COUNT(DISTINCT package_id) > 1
)
SELECT      DISTINCT
            pg.package_id,
            pg.name AS [PackageName],
            pj.project_id,
            pj.name AS [ProjectName],
            pg.package_guid,
            pg.version_guid,
            pg.version_build,
            mp.[NumOfSameNamePackages],
            pj.last_deployed_time,
            pj.deployed_by_name
            
FROM
            catalog.packages pg
INNER JOIN  catalog.projects pj ON pj.project_id = pg.project_id
INNER JOIN  MultiprojectPackageNames mp ON mp.name = pg.name
ORDER BY    mp.[NumOfSameNamePackages] DESC, pg.name, pj.name

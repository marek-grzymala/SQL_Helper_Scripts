DROP TABLE IF EXISTS [#TempTable]
CREATE TABLE [#TempTable] (
   ID int,
   City varchar(1000),
   Sales varchar(1000)
)
INSERT INTO [#TempTable] 
   (ID, City, Sales)
VALUES   
   (1, 'London,New York,Paris,Berlin,Madrid', '20,30,,50'),
   (2, 'Istanbul,Tokyo,Brussels,Kraków',           '4,5,6')

SELECT d.ID, a.City, a.Sales
FROM [#TempTable] d
CROSS APPLY (
   SELECT c.[value] AS City, s.[value] AS Sales
   FROM OPENJSON(CONCAT('["', REPLACE(d.City, ',', '","'), '"]')) c
   LEFT OUTER JOIN OPENJSON(CONCAT('["', REPLACE(d.Sales, ',', '","'), '"]')) s 
      ON c.[key] = s.[key]
) a 

DROP TABLE IF EXISTS [#TempTable1]
CREATE TABLE [#TempTable1] (
   ID INT,
   WaitResource VARCHAR(1000)
)
TRUNCATE TABLE [#TempTable1]

INSERT INTO [#TempTable1] 
   (ID, WaitResource)
VALUES   
   (1, 'PAGE: 17:1:38512 '),
   (2, 'PAGE: 17:1:9807 ' )

SELECT * FROM [#TempTable1]

DECLARE @ResourceTypes VARCHAR(32) = 'DbId:FileId:PageId'

;WITH [Unpivoted]
AS (SELECT [d].[ID]
         , [a].[ResourceType]
         , [a].[WaitResource]
    FROM [#TempTable1] [d]
    CROSS APPLY (
                    SELECT [c].[value] AS [WaitResource]
                         , [s].[Value] AS [ResourceType]
                    FROM OPENJSON(CONCAT('["', REPLACE(SUBSTRING([d].[WaitResource], 6, LEN([d].[WaitResource])), ':', '","'), '"]')) [c]
                    LEFT OUTER JOIN OPENJSON(CONCAT('["', REPLACE(@ResourceTypes, ':', '","'), '"]')) [s]
                        ON [c].[key] = [s].[key]
                ) [a] 
    )
SELECT [Unpivoted].[ID]
     , MAX(CASE WHEN [Unpivoted].[ResourceType] = 'DbId' THEN TRIM([Unpivoted].[WaitResource])END) AS [DbId]
     , MAX(CASE WHEN [Unpivoted].[ResourceType] = 'FileId' THEN TRIM([Unpivoted].[WaitResource])END) AS [FileId]
     , MAX(CASE WHEN [Unpivoted].[ResourceType] = 'PageId' THEN TRIM([Unpivoted].[WaitResource])END) AS [PageId]
FROM [Unpivoted]
GROUP BY [Unpivoted].[ID];
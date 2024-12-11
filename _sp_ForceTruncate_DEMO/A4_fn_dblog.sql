USE [TestDB]
GO

DECLARE @maxlns NVARCHAR(23)

--SELECT @maxlns = MAX([Current LSN])FROM [sys].[fn_dblog](NULL, NULL);
SELECT @maxlns = '0000002b:00006d70:002f'

DBCC TRACEON(2537);

SELECT [Current LSN]
     , [Operation]
     , [dblog].[Transaction ID]
     , [dblog1].[Transaction Name]
     , [AllocUnitId]
     , [AllocUnitName]
     , [description]
     , CONVERT(INT, CONVERT(VARBINARY, SUBSTRING([Page ID], CHARINDEX(':', [Page ID]) + 1, LEN([Page ID])), 2)) AS [PageId]
     , [Slot ID]
     , [Num Elements]
     , [dblog1].[Begin Time]
     , [dblog1].[Transaction Name]
     , [RowLog Contents 0]
     , [Log Record]
FROM ::fn_dblog(NULL, NULL) dblog
INNER JOIN (
               SELECT [allocunits].[allocation_unit_id]
                    , [objects].[name]
                    , [objects].[id]
               FROM [sys].[allocation_units] [allocunits]
               INNER JOIN [sys].[partitions] [partitions]
                   ON ([allocunits].[type] IN ( 1, 3 ) AND [partitions].[hobt_id] = [allocunits].[container_id])
                   OR ([allocunits].[type] = 2 AND [partitions].[partition_id] = [allocunits].[container_id])
               INNER JOIN [sys].[sysobjects] [objects]
                   ON  [partitions].[object_id] = [objects].[id]
                   AND [objects].[type] IN ( 'U', 'u' )
               WHERE [partitions].[index_id] IN ( 0, 1 )
           ) [allocunits]
    ON [dblog].[AllocUnitID] = [allocunits].[allocation_unit_id]
INNER JOIN (
               SELECT [x].[Begin Time]
                    , [x].[Transaction Name]
                    , [x].[Transaction ID]
               FROM [sys].[fn_dblog](NULL, NULL) [x]
               --WHERE [x].[Operation] = 'LOP_BEGIN_XACT'
           ) [dblog1]
    ON [dblog1].[Transaction ID] = [dblog].[Transaction ID]
WHERE 1 = 1
--AND   [Page ID] IS NOT NULL
--AND   [Slot ID] >= 0
--AND   [dblog].[Transaction ID] >= '0000:00001fe5' -- <> '0000:00000000'
--AND   [Context] IN ( 'LCX_HEAP', 'LCX_CLUSTERED' )
AND [Current LSN] > @maxlns
ORDER BY [Current LSN] DESC;

DBCC TRACEOFF(2537);

--SELECT * FROM [sys].[fn_dblog](NULL, NULL) WHERE [Transaction Name] LIKE '%Deferred%'
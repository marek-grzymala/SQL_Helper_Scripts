USE [TestDB]
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS [#PageNumbers]
DROP TABLE IF EXISTS [#DbccPageResultsBeforeTruncate]
DROP TABLE IF EXISTS [#DbccPageResultsAfterTruncate]

CREATE TABLE [#PageNumbers]
(
    [RowId]                  INT NOT NULL IDENTITY (1, 1) PRIMARY KEY CLUSTERED   
  , [allocated_page_file_id] INT NOT NULL
  , [allocated_page_page_id] INT NOT NULL
)

CREATE TABLE [#DbccPageResultsBeforeTruncate]
(
    [RowId]        INT           NOT NULL IDENTITY (1, 1) PRIMARY KEY CLUSTERED 
  , [PageId]       INT           NULL
  , [ParentObject] NVARCHAR(255) NOT NULL
  , [Object]       NVARCHAR(255) NOT NULL
  , [Field]        NVARCHAR(255) NOT NULL
  , [VALUE]        NVARCHAR(255) NOT NULL
);
CREATE TABLE [#DbccPageResultsAfterTruncate]
(
    [RowId]        INT           NOT NULL IDENTITY (1, 1) PRIMARY KEY CLUSTERED 
  , [PageId]       INT           NULL
  , [ParentObject] NVARCHAR(255) NOT NULL
  , [Object]       NVARCHAR(255) NOT NULL
  , [Field]        NVARCHAR(255) NOT NULL
  , [VALUE]        NVARCHAR(255) NOT NULL
);

INSERT INTO [#PageNumbers] ([allocated_page_file_id], [allocated_page_page_id])
SELECT [dpa].[allocated_page_file_id]
     , [dpa].[allocated_page_page_id]
FROM   sys.schemas [s]
JOIN   sys.objects [o]
    ON [o].[schema_id] = [s].[schema_id]
CROSS APPLY [sys].dm_db_database_page_allocations(DB_ID(), [o].[object_id], NULL, NULL, 'DETAILED') [dpa]
WHERE [o].[name] = N'TestTable'
AND   [s].[name] = N'dbo'
AND   [dpa].[page_type_desc] = N'DATA_PAGE';
GO

/* ------------------------------------------------------------------------------------------- */

DBCC TRACEON(3604) WITH NO_INFOMSGS;
DECLARE @dbid INT = DB_ID()
      , @fileid INT
      , @pageid INT
      , @cmd NVARCHAR(MAX);

DECLARE [cur] CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
SELECT [allocated_page_file_id], [allocated_page_page_id] FROM [#PageNumbers] ORDER BY [RowId]

OPEN [cur];
FETCH NEXT FROM [cur]
INTO @fileid
   , @pageid;
WHILE @@FETCH_STATUS = 0
BEGIN
    
    SET @cmd = CONCAT('DBCC PAGE(', @dbid, ', ', @fileid, ', ', @pageid, ', 1) WITH TABLERESULTS;');
    INSERT INTO [#DbccPageResultsBeforeTruncate] ([ParentObject], [Object], [Field], [VALUE])
    --INSERT INTO [#DbccPageResultsAfterTruncate] ([ParentObject], [Object], [Field], [VALUE])
    EXEC(@cmd)
    PRINT(CONCAT('Executed: ', @cmd))

    UPDATE [#DbccPageResultsBeforeTruncate] SET [PageId] = @pageid WHERE [PageId] IS NULL 
    --UPDATE [#DbccPageResultsAfterTruncate] SET [PageId] = @pageid WHERE [PageId] IS NULL 
    
    FETCH NEXT FROM [cur]
    INTO @fileid
       , @pageid;
END;
CLOSE [cur];
DEALLOCATE [cur];

DBCC TRACEOFF(3604);

SELECT
      [b].[RowId]
    , [b].[PageId]
    , [b].[ParentObject]
    , [b].[Object]
    , [b].[Field]
    , [b].[VALUE] AS [VALUE_BEFORE]
    , [a].[VALUE] AS [VALUE_AFTER]
FROM  [#DbccPageResultsBeforeTruncate] AS [b]
LEFT JOIN [#DbccPageResultsAfterTruncate] AS [a]
ON 1 = 1
AND [a].[PageId]        = [b].[PageId]
AND [a].[Object]        = [b].[Object] 
AND [a].[Field]         = [b].[Field]
AND [a].[ParentObject]  = [b].[ParentObject]
WHERE [b].[Object] = 'Allocation Status'
--AND [a].[VALUE] <> [b].[VALUE]
ORDER BY [b].[PageId], [b].[RowId];


USE [master]
GO

DECLARE @UseDeafultDataFilesPath BIT = 1
DECLARE @ManualDataFilesPath NVARCHAR(256) = NULL --'F:\ENTER THE PATH YOU WANT TO SEARCH HERE and set @UseDeafultDataFilesPath = 0'

DECLARE @FolderToMoveFilesInto NVARCHAR(256) = 'U:\ORPHANED_DB_FILES_TO_BE_DELETED\'
DECLARE @DBFilesPath NVARCHAR(256)

DECLARE @DeafultDataFilesPath NVARCHAR(256)
IF (@UseDeafultDataFilesPath = 1)
BEGIN
	SELECT TOP 1 @DeafultDataFilesPath = physical_name FROM master.sys.database_files df WHERE df.type = 0
	PRINT '@DeafultDataFilesPath Full: '+@DeafultDataFilesPath
	SET @DeafultDataFilesPath = REVERSE(STUFF(REVERSE(@DeafultDataFilesPath), 1, CHARINDEX('\', REVERSE(@DeafultDataFilesPath)), ''))
	PRINT '@DeafultDataFilesPath Adjusted: '+@DeafultDataFilesPath
END

IF (@UseDeafultDataFilesPath = 1)
BEGIN
	DECLARE @DefaultData nvarchar(512)
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DefaultData OUTPUT
	
	DECLARE @MasterData nvarchar(512)
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg0', @MasterData OUTPUT
	SELECT @MasterData=SUBSTRING(@MasterData, 3, 255)
	SELECT @MasterData=SUBSTRING(@MasterData, 1, LEN(@MasterData) - CHARINDEX('\', reverse(@MasterData)))
	
	SELECT @DBFilesPath = ISNULL(@DefaultData, @MasterData)+'\'
END
IF (@UseDeafultDataFilesPath = 0 AND @ManualDataFilesPath IS NOT NULL)
BEGIN
	SET @DBFilesPath = @ManualDataFilesPath+'\'
END
PRINT '@DBFilesPath: '+@DBFilesPath


DECLARE @cmd NVARCHAR(256) = 'DIR '+@DBFilesPath+' /TA'

IF OBJECT_ID('tempdb..#cmdShellResults') IS NOT NULL
      DROP TABLE #cmdShellResults;
CREATE TABLE #cmdShellResults
		(
			row VARCHAR(400)
		)

INSERT	#cmdShellResults
	(
		row
	)
EXEC master..xp_cmdshell @cmd
--SELECT * FROM #cmdShellResults

IF OBJECT_ID('tempdb..#FileListing') IS NOT NULL
      DROP TABLE #FileListing;
CREATE TABLE #FileListing
		(
			FileName VARCHAR(256)
			, FileDateAccessed VARCHAR(256)
			, FileSize VARCHAR(256)
		)
; WITH FileListing AS
(
SELECT	
	[FileName] = SUBSTRING(row, 37, 400),
	[FileDateAccessed] = SUBSTRING(row, 1, 17),
	[FileSize] = REPLACE(REPLACE(REPLACE(SUBSTRING(row, 18, 19), CHAR(160), ''), CHAR(32), ''), ',', '')
FROM	
	#cmdShellResults
) 
INSERT INTO #FileListing (FileName, FileDateAccessed, FileSize) SELECT [FileName], [FileDateAccessed], [FileSize] FROM FileListing
WHERE [FileName] LIKE '%.mdf' OR [FileName] LIKE '%.ndf' OR [FileName] LIKE '%.ldf'
-- fl.[FileSize] NOT LIKE '%[^0-9]%' 
--SELECT * FROM #FileListing

SELECT	
	fl.FileName 
	, CONVERT(DECIMAL(38,2),  CAST(fl.[FileSize] AS NUMERIC)) AS [FileSizeB]
	, CONVERT(DECIMAL(38,2), (CAST(fl.[FileSize] AS NUMERIC))/1024) AS [FileSizeKB]
	, CONVERT(DECIMAL(38,2), (CAST(fl.[FileSize] AS NUMERIC))/1024/1024) AS [FileSizeMB]
	, COALESCE(TRY_PARSE([FileDateAccessed] AS SMALLDATETIME USING 'en-US'), TRY_PARSE([FileDateAccessed] AS SMALLDATETIME USING 'en-GB')) AS [FileDateAccessed]
	, 'move '+@DBFilesPath+fl.[FileName]+' '+@FolderToMoveFilesInto+fl.[FileName] AS [MoveCommand]
FROM	
	#FileListing AS fl
LEFT OUTER JOIN sys.master_files m ON (REPLACE(m.[physical_name], @DBFilesPath, '')) = fl.[FileName]
WHERE m.[physical_name] IS NULL
ORDER BY [FileSizeKB] DESC
GO

IF OBJECT_ID('tempdb..#cmdShellResults') IS NOT NULL
      DROP TABLE #cmdShellResults;
GO


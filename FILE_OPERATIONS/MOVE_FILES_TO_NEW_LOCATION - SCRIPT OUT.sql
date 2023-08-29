DECLARE @NewFolderToMoveFilesInto NVARCHAR(256) = 'U:\TEMP_DWH_PRE_PROD\'

Create Table ##temp
(
    DatabaseName sysname,
    Name sysname,
    physical_name nvarchar(500),
    size decimal (18,2),
    FreeSpace decimal (18,2)
)   
Exec sp_msforeachdb '
Use [?];
Insert Into ##temp (DatabaseName, Name, physical_name, Size, FreeSpace)
    Select DB_NAME() AS [DatabaseName], Name,  physical_name,
    Cast(Cast(Round(cast(size as decimal) * 8.0/1024.0,2) as decimal(18,2)) as nvarchar) Size,
    Cast(Cast(Round(cast(size as decimal) * 8.0/1024.0,2) as decimal(18,2)) -
        Cast(FILEPROPERTY(name, ''SpaceUsed'') * 8.0/1024.0 as decimal(18,2)) as nvarchar) As FreeSpace
    From sys.database_files
'
SELECT --*
	DatabaseName as [DB Name]
	, physical_name as [Current File Physical Name]
	,'ALTER DATABASE ['+DatabaseName+'] MODIFY FILE (NAME = '+ Name + ', FILENAME = '''+@NewFolderToMoveFilesInto+RIGHT(physical_name, CHARINDEX('\', REVERSE(physical_name)) -1)+''');' AS [MODIFY FILE COMMANDS]
	, 'move '+physical_name+' '+@NewFolderToMoveFilesInto+RIGHT(physical_name, CHARINDEX('\', REVERSE(physical_name)) -1) AS [Move DOS Command]
	, size as [Size in MB]
	, FreeSpace as [Free Space in MB] 

FROM ##temp
--WHERE DatabaseName IN ('ACIA_DWH')
--physical_name LIKE '%DataA%'
ORDER BY FreeSpace DESC, DatabaseName --[DB Size in MB] DESC

DROP TABLE ##temp
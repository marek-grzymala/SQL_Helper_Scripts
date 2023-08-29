EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
EXEC sp_configure 'xp_cmdshell', 1
GO
RECONFIGURE
GO
use tempdb
go

DECLARE @Path VARCHAR(2000);

SET @Path = 'C:\_SQL_Projects_AON\DevInsurers_Restore\*.dtsx';

DECLARE @MyFiles TABLE (MyID INT IDENTITY(1,1) PRIMARY KEY, FullPath VARCHAR(2000));

DECLARE @CommandLine VARCHAR(4000) ;

SELECT @CommandLine =LEFT('dir "' + @Path + '" /A-D /B /S ',4000);

INSERT INTO @MyFiles (FullPath)

EXECUTE xp_cmdshell @CommandLine;

DELETE

FROM @MyFiles

WHERE FullPath IS NULL

OR FullPath = 'File Not Found'

OR FullPath = 'The system cannot find the path specified.'

OR FullPath = 'The system cannot find the file specified.'

OR FullPath like '%backup%';

IF EXISTS (select * from sys.tables where name = N'pkgStats')

DROP TABLE pkgStats;

CREATE TABLE pkgStats(

PackagePath varchar(900) NOT NULL PRIMARY KEY

, PackageXML XML NOT NULL

);

DECLARE @FullPath varchar(2000);

DECLARE file_cursor CURSOR

FOR SELECT FullPath FROM @MyFiles;

OPEN file_cursor

FETCH NEXT FROM file_cursor INTO @FullPath;

WHILE @@FETCH_STATUS = 0

BEGIN

declare @sql nvarchar(max);

SET @sql = '

INSERT pkgStats (PackagePath,PackageXML)

select  ''@FullPath'' as PackagePath

, cast(BulkColumn as XML) as PackageXML

from    openrowset(bulk ''@FullPath'',

single_blob) as pkgColumn';

SELECT @sql = REPLACE(@sql, '@FullPath', @FullPath);

EXEC sp_executesql @sql;

FETCH NEXT FROM file_cursor INTO @FullPath;

END

CLOSE file_cursor;

DEALLOCATE file_cursor;

SELECT SUBSTRING(PackagePath,LEN(PackagePath) - CHARINDEX('\',REVERSE(PackagePath),0)+2,LEN(PackagePath)) AS PackageName

, PackagePath

, CASE WHEN PackageFormatVersion = '3'

THEN VersionBuild

WHEN PackageFormatVersion = '6'

THEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(SUBSTRING(VersionBuild2, CHARINDEX('VersionBuild="', VersionBuild2), 20), 'VersionBuild="', ''), '"', ''), ' ', ''), 'D', ''), 'T', ''), 'S', ''), '<:Execuablexml', '')

END AS VersionBuild

, CreatorName

, ProtectionLevel

, PackageFormatVersion

, PackageType

, PackageDescription

, VersionMajor

, VersionMinor

, VersionGUID

, COUNT(*) AS NumberOfTasks

FROM (

select PackagePath

, PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''CreatorName''][1]','nvarchar(500)') AS CreatorName

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''ProtectionLevel''][1]','char(38)') AS char(38)) AS ProtectionLevel

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''PackageFormatVersion''][1]','varchar(3)') AS smallint) AS PackageFormatVersion

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

DTS:Executable[1]/@DTS:ExecutableType[1]','varchar(50)') AS varchar(50)) AS PackageType

, PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''Description''][1]','nvarchar(2000)') AS PackageDescription

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''VersionMajor''][1]','varchar(3)') AS smallint) AS VersionMajor

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''VersionMinor''][1]','varchar(3)') AS smallint) AS VersionMinor

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''VersionBuild''][1]','varchar(4)') AS smallint) AS VersionBuild

, CAST(PackageXML AS nvarchar(MAX)) AS VersionBuild2

, CAST(PackageXML.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

/DTS:Executable[1]/DTS:Property[@DTS:Name=''VersionGUID''][1]','char(38)') AS char(38)) AS VersionGUID

, PackageXML

from pkgStats

) p

CROSS    APPLY p.PackageXML.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts";

                           //DTS:Executable[@DTS:ExecutableType!=''STOCK:SEQUENCE''

                       and    @DTS:ExecutableType!=''STOCK:FORLOOP''

                       and    @DTS:ExecutableType!=''STOCK:FOREACHLOOP''

                       and not(contains(@DTS:ExecutableType,''.Package.''))]') Pkg(props)

GROUP BY PackagePath

, CreatorName

, ProtectionLevel

, PackageFormatVersion

, PackageType

, PackageDescription

, VersionMajor

, VersionMinor

, VersionBuild

, VersionBuild2

, VersionGUID;

--now disable xp_cmdshell:
EXEC sp_configure 'xp_cmdshell', 0
GO
EXEC sp_configure 'show advanced options', 0
GO
RECONFIGURE
GO
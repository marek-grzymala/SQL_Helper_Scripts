USE [YourDatabaseName]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE SCHEMA [sox]
GO

CREATE TABLE [sox].[ADGroup](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[groupName] [varchar](100) NULL,
	[isActive] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[groupName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET IDENTITY_INSERT [sox].[ADGroup] ON 
GO
INSERT [sox].[ADGroup] ([ID], [groupName], [isActive]) VALUES (1, N'AD_offending_group1', 1)
GO
INSERT [sox].[ADGroup] ([ID], [groupName], [isActive]) VALUES (2, N'AD_offending_group2', 1)
GO
INSERT [sox].[ADGroup] ([ID], [groupName], [isActive]) VALUES (3, N'AD_offending_group3', 1)
GO
SET IDENTITY_INSERT [sox].[ADGroup] OFF
GO

CREATE TABLE [sox].[ADUser](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[accountName] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[accountName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [sox].[ADUserDetails](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ADUserKey] [int] NOT NULL,
	[l_givenName] [varchar](100) NULL,
	[l_sn] [varchar](100) NULL,
	[l_displayName] [varchar](100) NULL,
	[l_userPrincipalName] [varchar](100) NULL,
	[l_co] [varchar](100) NULL,
	[l_department] [varchar](100) NULL,
	[l_title] [varchar](100) NOT NULL,
	[l_manager] [varchar](100) NOT NULL,
	[l_userAccountControl] [varchar](100) NOT NULL,
	[hashvalue] [varbinary](max) NOT NULL,
	[TSFrom] [datetime] NOT NULL,
	[TSTo] [datetime] NOT NULL,
	[isActive] [char](1) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_givenName]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_sn]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_displayName]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_userPrincipalName]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_co]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_department]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_title]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_manager]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('') FOR [l_userAccountControl]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('1900-01-01 00:00:00') FOR [TSFrom]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('2099-12-31 23:59:59') FOR [TSTo]
GO

ALTER TABLE [sox].[ADUserDetails] ADD  DEFAULT ('Y') FOR [isActive]
GO

CREATE TABLE [sox].[ADUserStatic](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[accountName] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[accountName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET IDENTITY_INSERT [sox].[ADUserStatic] ON 
GO
INSERT [sox].[ADUserStatic] ([ID], [accountName]) VALUES (1, N'StaticUser1')
GO
INSERT [sox].[ADUserStatic] ([ID], [accountName]) VALUES (2, N'StaticUser2')
GO
SET IDENTITY_INSERT [sox].[ADUserStatic] OFF
GO

CREATE TABLE [sox].[GroupsUsers](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[groupID] [int] NOT NULL,
	[userID] [int] NOT NULL,
	[TSFrom] [datetime] NOT NULL,
	[TSTo] [datetime] NOT NULL,
	[isActive] [char](1) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [sox].[GroupsUsers] ADD  DEFAULT ('Y') FOR [isActive]
GO

CREATE TABLE [sox].[GroupsUsersTransformationLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[TSStart] [datetime] NULL,
	[TSEnd] [datetime] NULL,
	[CountGUNewRecords] [int] NULL,
	[CountGUClosedRecords] [int] NULL,
	[CountUserDetilsUpdatedRecords] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE PROCEDURE [sox].[getGroupUsers]
	
AS
BEGIN
	/*
		-- cleaning:
		TRUNCATE TABLE [sox].[ADUser]
		TRUNCATE TABLE [sox].[ADUserDetails]
		TRUNCATE TABLE [sox].[GroupsUsers]
		TRUNCATE TABLE [sox].[GroupsUsersTransformationLog]

		CREATE TABLE sox.ADGroup (
			ID INT PRIMARY KEY IDENTITY(1,1)
			, groupName VARCHAR(100) UNIQUE
			, isActive INT
		)

		TRUNCATE TABLE sox.ADGroup
		INSERT INTO sox.ADGroup  (groupName, isActive)
		VALUES 
			('EUAG-GRP_EMEA_DWH_feeds', 1)
			, ('EUAG-GRP_EMEA_DWH_Members', 1)
			, ('EUAG-GRP_EMEA_DWH_Support', 1)			


		CREATE TABLE sox.ADUser (
			ID INT PRIMARY KEY IDENTITY(1,1)
			, accountName VARCHAR(100) UNIQUE
		)

		DROP TABLE sox.GroupsUsers 
		CREATE TABLE sox.GroupsUsers (
			ID INT PRIMARY KEY IDENTITY(1,1)
			, groupID INT NOT NULL
			, userID INT NOT NULL
			, TSFrom DATETIME NOT NULL
			, TSTo DATETIME NOT NULL
			, isActive CHAR(1) DEFAULT 'Y'
		)

		DROP TABLE sox.GroupsUsersTransformationLog
		CREATE TABLE sox.GroupsUsersTransformationLog (
			ID INT PRIMARY KEY IDENTITY(1,1)
			, TSStart DATETIME
			, TSEnd DATETIME
			, CountGUNewRecords INT
			, CountGUClosedRecords INT
			, CountUserDetilsUpdatedRecords INT
		)

		TRUNCATE TABLE sox.ADUserDetails
		DROP TABLE sox.ADUserDetails
		CREATE TABLE sox.ADUserDetails (
			ID INT NOT NULL PRIMARY KEY IDENTITY(1,1)
			, ADUserKey INT NOT NULL
			, l_givenName VARCHAR(100) DEFAULT ''
			, l_sn VARCHAR(100) DEFAULT ''
			, l_displayName VARCHAR(100) DEFAULT ''
			, l_userPrincipalName VARCHAR(100) DEFAULT ''
			, l_co VARCHAR(100) DEFAULT ''
			, l_department VARCHAR(100) DEFAULT ''
			, l_title VARCHAR(100) NOT NULL DEFAULT ''
			, l_manager VARCHAR(100) NOT NULL DEFAULT ''
			, l_userAccountControl VARCHAR(100) NOT NULL DEFAULT ''
			, hashvalue VARBINARY(MAX) NOT NULL
			, TSFrom DATETIME NOT NULL DEFAULT '1900-01-01 00:00:00'
			, TSTo DATETIME NOT NULL DEFAULT '2099-12-31 23:59:59'
			, isActive CHAR(1) NOT NULL DEFAULT 'Y'
		)
	*/
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--=====================================================================
	-- GLOBAL VARIABLES & TEMP TABLES
	--=====================================================================
	DECLARE @tsTransformationStart DATETIME = CONVERT(VARCHAR(19), GETDATE(), 120)
	DECLARE @tsto DATETIME = '2099-12-31 23:59:59'
	DECLARE @sql NVARCHAR(MAX) = ''
	
	-- Temp table to get current groups members
	IF OBJECT_ID('tempdb..#groupsMembers') IS NOT NULL
		DROP TABLE #groupsMembers

	CREATE TABLE #groupsMembers (
		groupName VARCHAR(100)
		, accountName VARCHAR(100)
		, userName VARCHAR(100)
	)

	-- Temp table for logs from merge operations
	IF OBJECT_ID('tempdb..#SummaryOfChanges') IS NOT NULL 
		DROP TABLE #SummaryOfChanges

	CREATE TABLE #SummaryOfChanges (
		tableName VARCHAR(100)
		, accountName VARCHAR(100)
		, actionName VARCHAR(100)	
	)	

	-- Temp table for detail informations about users
	IF OBJECT_ID('tempdb..#userDetails') IS NOT NULL
		DROP TABLE #userDetails

	CREATE TABLE #userDetails (
		accountName VARCHAR(100) NOT NULL
		, l_givenName VARCHAR(100) NOT NULL DEFAULT ''
		, l_sn VARCHAR(100) NOT NULL DEFAULT ''
		, l_displayName VARCHAR(100) NOT NULL DEFAULT ''
		, l_userPrincipalName VARCHAR(100) NOT NULL DEFAULT ''
		, l_co VARCHAR(100) NOT NULL DEFAULT ''
		, l_department VARCHAR(100) NOT NULL DEFAULT ''
		, l_title VARCHAR(100) NOT NULL DEFAULT ''
		, l_manager VARCHAR(100) NOT NULL DEFAULT ''
		, l_userAccountControl VARCHAR(100) NOT NULL DEFAULT ''
		, hashvalue VARBINARY(MAX)
	)


	--=====================================================================
	-- GET USERS FOR DEFINED GROUPS (sox.ADGroup)
	--=====================================================================
	DECLARE @groupName VARCHAR(100) = ''
	DECLARE @groupDistinguishedName VARCHAR(100) = ''

	-- Cursor for every group
	DECLARE CUR CURSOR FOR
	SELECT groupName
	FROM sox.ADGroup 
	WHERE isActive = 1
	ORDER BY ID

	OPEN CUR	

	FETCH NEXT FROM CUR INTO @groupName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT @groupName

		-- get distinguished name of group
		SET @sql = '
			SELECT @groupDistinguishedName = distinguishedName
			FROM OpenQuery ( 
				ADSI_new
				, ''
				SELECT distinguishedName
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''group''''
					AND cn = ''''' + @groupName + '''''	
				''
			) AS tbl
		'
		EXEC sp_executesql @sql, N'@groupDistinguishedName VARCHAR(1000) OUTPUT', @groupDistinguishedName = @groupDistinguishedName OUTPUT

		-- get members of group
		SET @sql = '
			SELECT 
					''' + @groupName + ''' AS gr
					, sAMAccountName
					, displayName
			FROM OpenQuery ( 
				ADSI_new
				, ''
				SELECT givenName, sn, displayName, userPrincipalName, sAMAccountName, co, department, title
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''user''''
					AND memberof = ''''' + @groupDistinguishedName + '''''
				'') AS tblADSI
			ORDER BY userPrincipalName
		'
		INSERT INTO #groupsMembers (groupName, accountName, userName)	
		EXEC (@sql)

		FETCH NEXT FROM CUR INTO @groupName
	END

	CLOSE CUR
	DEALLOCATE CUR

	-- Add static users which have to be monitored regardless group membership
	INSERT INTO sox.ADUser (accountName)
	SELECT accountName
	FROM sox.ADUserStatic us
	WHERE NOT EXISTS (
		SELECT 1
		FROM sox.ADUser u
		WHERE u.accountName = us.accountName
	)

	-- Add new Users to ADUser table
	INSERT INTO sox.ADUser (accountName)
	SELECT DISTINCT RTRIM(LTRIM(g.accountName))			-- many groups
	FROM #groupsMembers g
	WHERE NOT EXISTS (
		SELECT 1
		FROM sox.ADUser u
		WHERE u.accountName = g.accountName
	)

	--=====================================================================
	-- MERGE - GET GROUP USER CONNECTIONS
	--=====================================================================
	-- test for merge 
	/*
	-- update some rows from sox.GroupsUsers as inactive to show that they will be inserted again within next transformation
	UPDATE sox.GroupsUsers
	SET TSTo = DATEADD(S, -1, @tsTransformationStart)
			, isActive = 'N'
	WHERE groupID = 1 
		AND userID IN (16, 20)

	-- delete some rows from temp table to show that existsing ros in sox.GroupUsers will be closed
	delete from #groupsMembers where accountName = 'TestUser'
	*/

	MERGE sox.GroupsUsers t
		USING (	
			SELECT 
					g.ID				AS groupID
					, u.ID				AS userID
					, u.accountName
			FROM #groupsMembers gm

				LEFT JOIN sox.ADGroup g
					ON g.groupName = gm.groupName

				LEFT JOIN sox.ADUser u
					ON u.accountName = gm.accountName 
		) s
			ON s.groupID = t.groupID
				AND s.userID = t.userID
				AND t.TSTo = '2099-12-31 23:59:59'

			-- no record in final table - new record (insert as open and acitve)
			WHEN NOT MATCHED THEN
				INSERT (groupID, userID, TSFrom, TSTo, isActive)
				VALUES (s.groupID, s.userID, @tsTransformationStart, '2099-12-31 23:59:59', 'Y')

			-- a record no longer exists in source - close record and deactivate
			WHEN NOT MATCHED BY SOURCE AND TSTo = '2099-12-31 23:59:59' THEN
				UPDATE SET TSTo = DATEADD(S, -1, @tsTransformationStart)
							, isActive = 'N'

			OUTPUT 'GroupsUsers', s.accountName, $action INTO #SummaryOfChanges
	;

	--=============================
	-- GET USER DETAILS
	--=============================
	DECLARE @user VARCHAR(100) = ''

	DECLARE CUR CURSOR FOR
	SELECT	accountName
	FROM sox.ADUser

	OPEN CUR

	FETCH NEXT FROM CUR INTO @user

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT @user
		
		-- get user details:
		SET @sql = '
			SELECT 
					''' + @user + '''
					, ISNULL(givenName, '''')
					, ISNULL(sn, '''')
					, ISNULL(displayName, '''')
					, ISNULL(userPrincipalName, '''')
					, ISNULL(co, '''')
					, ISNULL(department, '''')
					, ISNULL(title, '''')
					, ISNULL(SUBSTRING(manager, 4, CHARINDEX('','', manager) - 4), '''') AS manager
					, ISNULL(userAccountControl, '''')
			FROM OpenQuery ( 
				ADSI_new
				, ''
				SELECT givenName, sn, displayName, userPrincipalName, sAMAccountName, co, department, cn, manager, userAccountControl, title
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''user''''
					AND sAMAccountName = ''''' + @user + '''''
				'') AS tblADSI
			ORDER BY userPrincipalName
		'
		
		INSERT INTO #userDetails (
			accountName, l_givenName, l_sn, l_displayName, l_userPrincipalName, l_co, l_department, l_title, l_manager, l_userAccountControl
		)
		EXEC (@sql)
	
		FETCH NEXT FROM CUR INTO @user
	END

	CLOSE CUR
	DEALLOCATE CUR

	-- hash calculation
	UPDATE #userDetails
	SET hashvalue =  HASHBYTES('SHA1' , l_givenName + l_sn + l_displayName + l_userPrincipalName + l_co + l_department + l_title + l_manager + l_userAccountControl)

	--=============================
	-- MERGE - GET USER DETAILS
	--=============================
	-- test for merge
	/*
	-- update country for downloaded data and hashvalue to show that current record will be closed and the new one will be inserted
	UPDATE #userDetails
	SET l_co = 'Germany'
	WHERE accountName = 'TestAccount'

	UPDATE #userDetails
	SET hashvalue = HASHBYTES('SHA1' , l_givenName + l_sn + l_displayName + l_userPrincipalName + l_co + l_department + l_title + l_manager + l_userAccountControl)
	WHERE accountName = 'TestAccount'
	*/

	MERGE sox.ADUserDetails t
		USING (	
			SELECT 
					u.ID		AS userKey
					, ud.*
			FROM #userDetails ud

				LEFT JOIN sox.ADUser u
					ON u.accountName = ud.accountName

		) s
			ON s.userKey = t.ADUserKey
				AND s.hashvalue = t.hashvalue
				AND TSTo = '2099-12-31 23:59:59'

			-- no record in final table - new record (insert as open and acitve)
			WHEN NOT MATCHED THEN
				INSERT (ADUserKey, l_givenName, l_sn, l_displayName, l_userPrincipalName, l_co, l_department, l_title, l_manager, l_userAccountControl, hashvalue, TSFrom, TSTo, isActive)
				VALUES (s.userKey, s.l_givenName, s.l_sn, s.l_displayName, s.l_userPrincipalName, s.l_co, s.l_department, l_title, l_manager, l_userAccountControl, s.hashvalue, @tsTransformationStart, '2099-12-31 23:59:59', 'Y')

			-- a record no longer exists in source - close record and deactivate
			WHEN NOT MATCHED BY SOURCE AND TSTo = '2099-12-31 23:59:59' THEN
				UPDATE SET TSTo = DATEADD(S, -1, @tsTransformationStart)
							, isActive = 'N'

			OUTPUT 'ADUserDetails', s.accountName, $action INTO #SummaryOfChanges
	;

	--==================
	-- LOG
	--==================
	INSERT INTO sox.GroupsUsersTransformationLog (
		[TSStart]
		,[TSEnd]
		,[CountGUNewRecords]
		,[CountGUClosedRecords]
		,CountUserDetilsUpdatedRecords
	)

	SELECT 
			@tsTransformationStart
			, CONVERT(VARCHAR(19), GETDATE(), 120)
			, (SELECT COUNT(*) FROM #SummaryOfChanges WHERE actionName = 'INSERT' AND tableName = 'GroupsUsers')
			, (SELECT COUNT(*) FROM #SummaryOfChanges WHERE actionName = 'UPDATE' AND tableName = 'GroupsUsers')
			, (SELECT COUNT(DISTINCT accountName) FROM #SummaryOfChanges WHERE actionName IN ('INSERT', 'UPDATE') AND tableName = 'ADUserDetails')

	--=====================================================================
	-- REPORTS
	--=====================================================================
	-- log
	SELECT TOP 3 * 
	FROM sox.GroupsUsersTransformationLog
	ORDER BY ID DESC

	--users:
	/*
	-- all
	SELECT	
			groupName
			, accountName
	FROM sox.GroupsUsers gu

		LEFT JOIN sox.ADGroup g
			ON g.ID = gu.groupID

		LEFT JOIN sox.ADUser u
			ON u.ID = gu.userID

	WHERE gu.isActive = 'Y'

	ORDER BY groupName, accountName
	*/

	-- added
	SELECT	
			groupName
			, accountName
	FROM sox.GroupsUsers gu

		LEFT JOIN sox.ADGroup g
			ON g.ID = gu.groupID

		LEFT JOIN sox.ADUser u
			ON u.ID = gu.userID

	WHERE gu.isActive = 'Y'
		AND TSFrom = (SELECT MAX(TSStart) FROM sox.GroupsUsersTransformationLog)

	ORDER BY groupName, accountName

	-- deleted
	SELECT	
			groupName
			, accountName
	FROM sox.GroupsUsers gu

		LEFT JOIN sox.ADGroup g
			ON g.ID = gu.groupID

		LEFT JOIN sox.ADUser u
			ON u.ID = gu.userID

	WHERE gu.isActive = 'N'
		AND TSTo = (SELECT MAX(DATEADD(S, -1, TSStart)) FROM sox.GroupsUsersTransformationLog)

	ORDER BY groupName, accountName

	-- changed details:
	SELECT
			u.accountName
			, CASE ud.isActive
				WHEN 'N'			THEN 'deactivated'
									ELSE 'activated'
			END AS action
			, ud.l_givenName											AS FirstName
			, ud.l_sn													AS LastName
			, ud.l_displayName											AS DisplayName
			, ud.l_userPrincipalName									AS LogonName
			, ud.l_co													AS Country
			, ud.l_department											AS Department
			, ud.l_title												AS JobTitle
			, ISNULL(managerDetalis.l_displayName, ud.l_manager)		AS Manager
			, CASE ud.l_userAccountControl
				WHEN 512	THEN 'NORMAL'
				WHEN 514	THEN 'DISABLED'
							ELSE ud.l_userAccountControl
			END AS Account
			
	FROM sox.ADUserDetails ud

		LEFT JOIN sox.ADUser u
			ON u.ID = ud.ADUserKey

		LEFT JOIN sox.ADUser manager
			ON manager.accountName = ud.l_manager

		LEFT JOIN sox.ADUserDetails managerDetalis
			ON managerDetalis.ADUserKey = manager.ID
				AND managerDetalis.isActive = 'Y'

	WHERE (
			-- closed records:
			ud.isActive = 'N'
			AND ud.TSTo = (SELECT MAX(DATEADD(S, -1, TSStart)) FROM sox.GroupsUsersTransformationLog) 
		) OR (
			-- opened records:
			ud.isActive = 'Y'
			AND ud.TSFrom = (SELECT MAX(TSStart) FROM sox.GroupsUsersTransformationLog)
		)
	
	ORDER BY ud.isActive, action

END
GO

CREATE PROCEDURE [sox].[getPrivilegesReport]
	@server VARCHAR(100) = @@SERVERNAME
	, @db VARCHAR(100) = NULL
AS
BEGIN

SET @db = DB_NAME()
	--==================================================================================================
	--==================================================================================================
	--							1. Query to get all logins db (#allUsers)
	--==================================================================================================
	--==================================================================================================

	IF (OBJECT_ID('tempdb..#allUsers') IS NOT NULL)
		DROP TABLE #allUsers

	DECLARE @DB_USers TABLE
	(DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime)

	-- all users from db
	DECLARE @sql NVARCHAR(MAX) = '			
		SELECT 
			''' + @db + ''' AS DB_Name
			, case prin.name when ''dbo'' then prin.name + '' (''+ user_p.name + '')'' else prin.name end AS UserName
			, prin.type_desc AS LoginType
			, ISNULL(role_p.name, '''') AS AssociatedRole 
			, prin.create_date
			, prin.modify_date
		FROM ' + @server + '.' + @db + '.sys.database_principals prin
		
			LEFT OUTER JOIN ' + @server + '.' + @db + '.sys.database_role_members mem ON prin.principal_id=mem.member_principal_id

			LEFT JOIN ' + @server + '.' + @db + '.sys.database_principals role_p
				ON role_p.principal_id = mem.role_principal_id
					AND role_p.type = ''R''
					
			LEFT JOIN ' + @server + '.master.sys.databases d
				ON 1=1
					AND d.name = '+ @db +'
					
			LEFT JOIN ' + @server + '.' + @db + '.sys.database_principals user_p
				ON user_p.principal_id = d.owner_sid

		WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00)
			AND prin.is_fixed_role <> 1 
			AND prin.name NOT LIKE ''##%''
	'
	
	INSERT @DB_USers
	EXEC (@sql)

	
	-- grouping query above
	SELECT

	dbname,username ,logintype ,create_date ,modify_date ,

	STUFF(

	(

	SELECT ',' + CONVERT(VARCHAR(500),associatedrole)

	FROM @DB_USers user2

	WHERE

	user1.DBName=user2.DBName AND user1.UserName=user2.UserName

	FOR XML PATH('')

	)

	,1,1,'') AS Permissions_user

	INTO #allUsers

	FROM @DB_USers user1

	GROUP BY

	dbname,username ,logintype ,create_date ,modify_date

	ORDER BY DBName,username

	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--									2. User Logins details (#domainUsers)
	--==================================================================================================
	--==================================================================================================


	IF (OBJECT_ID('tempdb..#domainUsers') IS NOT NULL)
		DROP TABLE #domainUsers

	-- table with all domain users on db
	CREATE TABLE #domainUsers (
		givenName VARCHAR(100)
		, sn VARCHAR(100)
		, displayName VARCHAR(100)
		, userPrincipalName VARCHAR(100)
		, sAMAccountName VARCHAR(100)
		, country VARCHAR(100)
		, department VARCHAR(100)
		, title VARCHAR(100)
	)

	-- Cursor for all Domain windows users used in 
	DECLARE CUR CURSOR FOR
	SELECT DISTINCT SUBSTRING(UserName, 8, 100) AS UserName
	FROM #allUsers
	WHERE 1=1
		AND LoginType = 'WINDOWS_USER'		-- user
		AND UserName LIKE 'AD_DOMAIN_NAME%'			-- only AD_DOMAIN_NAME domain
	ORDER BY UserName

	DECLARE @userName VARCHAR(100) = ''

	OPEN CUR 
	FETCH NEXT FROM CUR INTO @userName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT @userName
		
		-- for every user get details
		SET @sql = '
			SELECT 
					givenName
					, sn
					, displayName
					, userPrincipalName
					, ''AD_DOMAIN_NAME\'' + sAMAccountName AS sAMAccountName
					, co
					, department
					, title
			FROM OpenQuery ( 
			  ADSI_new
			  , ''
				SELECT givenName, sn, displayName, userPrincipalName, sAMAccountName, co, department, title
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''user''''
					AND cn = ''''' + @userName + '''''	
			  '') AS tblADSI
			ORDER BY userPrincipalName
		'

		INSERT INTO #domainUsers (givenName, sn, displayName, userPrincipalName, sAMAccountName, country, department, title)	
		EXEC (@sql)
		FETCH NEXT FROM CUR INTO @userName
	END

	CLOSE CUR
	DEALLOCATE CUR
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--									3. Group member details (#domainGroups)
	--==================================================================================================
	--==================================================================================================

	IF (OBJECT_ID('tempdb..#domainGroups') IS NOT NULL)
		DROP TABLE #domainGroups

	-- table with expanded groups
	CREATE TABLE #domainGroups (
		groupName VARCHAR(100)
		, givenName VARCHAR(100)
		, sn VARCHAR(100)
		, displayName VARCHAR(100)
		, userPrincipalName VARCHAR(100)
		, sAMAccountName VARCHAR(100)
		, country VARCHAR(100)
		, department VARCHAR(100)
		, title VARCHAR(100)
	)

	-- Cursor for all AD_DOMAIN_NAME windows groups used in EMEA DWH
	DECLARE CUR CURSOR FOR
	SELECT DISTINCT UserName
	FROM #allUsers
	WHERE 1=1
		AND LoginType = 'WINDOWS_GROUP'		-- group
		AND UserName LIKE 'AD_DOMAIN_NAME%'			-- only AD_DOMAIN_NAME domain

	DECLARE @groupName VARCHAR(100) = '' --'AD_DOMAIN_NAME\EUAG-GRP_EMEA_DWH_Members'
	DECLARE @groupDistinguishedName VARCHAR(1000) = ''
	--DECLARE @sql NVARCHAR(MAX)

	OPEN CUR 
	FETCH NEXT FROM CUR INTO @groupName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT @groupName
		
		-- get distinguished name of group
		SET @sql = '
			SELECT @groupDistinguishedName = distinguishedName
			FROM OpenQuery ( 
				ADSI_new
				, ''
				SELECT distinguishedName
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''group''''
					AND cn = ''''' + SUBSTRING(@groupName, 8, 100) + '''''	
				''
			) AS tbl
		'
		EXEC sp_executesql @sql, N'@groupDistinguishedName VARCHAR(1000) OUTPUT', @groupDistinguishedName = @groupDistinguishedName OUTPUT

		-- get members of group
		SET @sql = '
			SELECT 
					''' + @groupName + ''' AS gr
					, givenName
					, sn
					, displayName
					, userPrincipalName
					, sAMAccountName
					, co
					, department
					, title
			FROM OpenQuery ( 
			  ADSI_new
			  , ''
				SELECT givenName, sn, displayName, userPrincipalName, sAMAccountName, co, department, title
				FROM  ''''LDAP://IP_ADDRESS_OF_YOUR_LDAP_SERVER''''
				WHERE objectClass = ''''user''''
					AND memberof = ''''' + @groupDistinguishedName + '''''
			  '') AS tblADSI
			ORDER BY userPrincipalName
		'

		INSERT INTO #domainGroups (groupName, givenName, sn, displayName, userPrincipalName, sAMAccountName, country, department, title)	
		EXEC (@sql)
		FETCH NEXT FROM CUR INTO @groupName
	END

	CLOSE CUR
	DEALLOCATE CUR
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--						4. Governance application access (Session access) (#govApp)
	--==================================================================================================
	--==================================================================================================

	IF (OBJECT_ID('tempdb..#govApp') IS NOT NULL)
		DROP TABLE #govApp

	CREATE TABLE #govApp (
		NTUserName VARCHAR(100)
		, FirstName VARCHAR(100)
		, LastName VARCHAR(100)
	)

	-- pivoted data from governance application
	SET @sql = '
		SELECT	DISTINCT
				NTUserName
				, FirstName
				, LastName
		
		FROM (
			SELECT DISTINCT 1 AS A
						, s.systemname + ISNULL(''_'' +NULLIF(LTRIM(RTRIM(s.systemcountrycode)), ''''), '''')		AS systemname
						, NTUserName																		
						, FirstName
						, LastName
						, CASE
							WHEN NTUserName IS NOT NULL	THEN 1
														ELSE 0
						END AS has_access
						
			FROM ' + @server + '.' + @db + '.dbo.system s

				LEFT JOIN ' + @server + '.' + @db + '.[gov].[RoleTableColumnValue] rtcv
					ON rtcv.Value = s.system_key
					
				LEFT JOIN ' + @server + '.' + @db + '.[gov].[TableColumn] tc
					ON tc.TableId = rtcv.TableId
						AND tc.ColumnId = rtcv.ColumnId
						AND tc.ColumnName = ''dim_aon_system_key''
					
				LEFT JOIN ' + @server + '.' + @db + '.[gov].[UserRole] ur
					ON ur.RoleId = rtcv.RoleId
					
				LEFT JOIN ' + @server + '.' + @db + '.[gov].[User] u
					ON u.UserId = ur.UserId
			            
			WHERE s.system_key <> 0
		) AS privileges

			PIVOT (
				MAX(has_access)
				FOR systemname IN ()		
			) AS pvt
			
		WHERE NTUserName IS NOT NULL
		ORDER BY	NTUserName
	'

	INSERT INTO #govApp
	EXEC (@sql)
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--==================================================================================================
	--								5. Join all data and print report
	--==================================================================================================
	--==================================================================================================

	SET @sql = '
		SELECT 
				u.DBName												AS dbname
				, dg.groupName											AS domaingroup
				, ISNULL(''AD_DOMAIN_NAME\'' + dg.sAMAccountName, u.UserName)	AS username
				, LoginType
				, u.create_date
				, u.modify_date
				, Permissions_user
				, l.hasaccess
				, sp.is_disabled
				
				-- LDAP
				, ISNULL(dg.sAMAccountName, du.sAMAccountName)			AS sAMAccountName
				, ISNULL(dg.displayName, du.displayName)				AS displayName			
				, ISNULL(dg.country, du.country)						AS country
				, ISNULL(dg.department, du.department)					AS department
				, ISNULL(dg.title, du.title)							AS title
				
		FROM #allUsers u

			LEFT JOIN #domainGroups dg
				ON dg.groupName = u.UserName
				
			LEFT JOIN #domainUsers du
				ON du.sAMAccountName = u.UserName
				
			LEFT JOIN ' + @server + '.' + @db + '.sys.syslogins l
				ON l.name = u.UserName
				
			LEFT JOIN ' + @server + '.' + @db + '.sys.server_principals sp
				ON sp.name = u.UserName
				
			LEFT JOIN #govApp ga
				ON ISNULL(''AD_DOMAIN_NAME\'' + dg.sAMAccountName, u.UserName) LIKE ''%'' + ga.NTUserName + ''%''
				
		ORDER BY dbname, u.UserName, username
	'
	EXEC (@sql)
END
GO


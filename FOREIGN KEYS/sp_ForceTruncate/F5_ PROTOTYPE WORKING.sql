/*

USE [RegisterTakeOn1_DEV_1]
GO
USE	[AdventureWorks2019]
GO

AuthenticationCode,PaymentChannel,Payment,PaymentOutHolding,PaymentOut,BalanceRelatedChange,CoverState,HoldingAddressHistory,RoleAddress,DateOfLastContact
PartyRole,Cover,AlternateReference,Book,RoleAddressHistory,Party,MembershipDate,HoldingElement,Indicator,Holding,Registration,TaxDetailRegistration,TaxDetail,TaxForm,Shareowner,Certificate,ContactDetails,PostalZoneCode,WorkItemTransaction,WorkRequest,ReserveDetail,Offering,CoverLegend,Equity,StockRegistrationOffering,TaxNotice,Legend,Client,DividendStockOffering,Mandate,ACHInternationalMandate,W9TaxForm
TaxSubOffering,SeasonalAddressDetail,ACHDomesticMandate,HoldingTaxFormRate,W8Treaty,HoldingStockCorporateActionCreditSubTaskCashDetail,HoldingStockCorporateActionCreditSubTaskAccruedDividendDetail,Check,HoldingStockCorporateActionTask,DividendStockOfferingTask,StandingBrokerInstructionBalanceRelatedChange,PartyEmployeeDetail,HoldingTaxFormRegionRate,StockSharedealingSaleOfferingBookChannelDetail,TaxResult,HoldingStockCorporateActionCreditSubTaskCashinLieuDetail,ContactDetailsDeliveryCategory,HoldingRequestTask,TaxResultForeign,HoldingStockDividendTask,StockSharedealingSaleOfferingBookChannelOrderType,

*/

USE [SIRIUS1_DEV_1]
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ########################################################## VARIABLE AND TEMP TABLE DECLARATIONS: ########################################## */

DECLARE @SchemaNames                         NVARCHAR(MAX) = N'dbo,'		  --N'Production,'	--N'Sales;Production;HumanResources;Person;'
      , @TableNames                          NVARCHAR(MAX) = N'AuthenticationCode,PaymentChannel,Payment,PaymentOutHolding,PaymentOut,BalanceRelatedChange,CoverState,HoldingAddressHistory,RoleAddress,DateOfLastContact
PartyRole,Cover,AlternateReference,Book,RoleAddressHistory,Party,MembershipDate,HoldingElement,Indicator,Holding,Registration,TaxDetailRegistration,TaxDetail,TaxForm,Shareowner,Certificate,ContactDetails,PostalZoneCode,WorkItemTransaction,WorkRequest,ReserveDetail,Offering,CoverLegend,Equity,StockRegistrationOffering,TaxNotice,Legend,Client,DividendStockOffering,Mandate,ACHInternationalMandate,W9TaxForm
TaxSubOffering,SeasonalAddressDetail,ACHDomesticMandate,HoldingTaxFormRate,W8Treaty,HoldingStockCorporateActionCreditSubTaskCashDetail,HoldingStockCorporateActionCreditSubTaskAccruedDividendDetail,Check,HoldingStockCorporateActionTask,DividendStockOfferingTask,StandingBrokerInstructionBalanceRelatedChange,PartyEmployeeDetail,HoldingTaxFormRegionRate,StockSharedealingSaleOfferingBookChannelDetail,TaxResult,HoldingStockCorporateActionCreditSubTaskCashinLieuDetail,ContactDetailsDeliveryCategory,HoldingRequestTask,TaxResultForeign,HoldingStockDividendTask,StockSharedealingSaleOfferingBookChannelOrderType,'  --N'Product,'	--N'SpecialOfferProduct;Product;Employee;BusinessEntity;Person;'
      , @Delimiter                           CHAR(1)       = ',' /* character used to delimit and terminate the item(s) in the lists above */


	  , @ReenableCDC						 BIT		   = 1                                                                 
      , @TruncateAllTablesPerDB              BIT           = 0   /* Set @TruncateAllTablesPerDB to = 1 ONLY if you want to ignore the @SchemaNames/@TableNames 
																	specified above and  drop/re-create commands for ALL FK constraints within the ENTIRE DB */

      , @ObjectId                            INT
      , @SchemaId                            INT
      , @StartSearchSch                      INT
      , @DelimiterPosSch                     INT
      , @SchemaName                          SYSNAME
      , @TableName                           SYSNAME
      , @StartSearchTbl                      INT
      , @DelimiterPosTbl                     INT
      , @SqlEngineVersion                    INT
      , @LineId                              INT
      , @LineIdMax                           INT
      , @BatchSize                           INT           = 10
      , @PercentProcessed                    INT           = 0
      
	  , @SqlCte                              NVARCHAR(MAX)
      , @SqlSelect                           NVARCHAR(MAX)
      , @SqlInsert                           NVARCHAR(MAX)
      , @SqlSchemaId                         NVARCHAR(MAX)
      , @SqlDropConstraint                   NVARCHAR(MAX)
      , @SqlDropView                         NVARCHAR(MAX)
      , @SqlTruncateTable                    NVARCHAR(MAX)
	  , @SqlUpdateStatistics				 NVARCHAR(MAX)
      , @SqlRecreateConstraint               NVARCHAR(MAX)
      , @SqlRecreateView                     NVARCHAR(MAX)
      , @SqlXtndProperties                   NVARCHAR(MAX)
      , @SqlTableCounts                      NVARCHAR(MAX)

	  , @CDC_source_schema					 SYSNAME
	  , @CDC_source_name					 SYSNAME
	  , @CDC_capture_instance				 SYSNAME
	  , @CDC_role_name						 SYSNAME
	  , @CDC_filegroup_name					 SYSNAME
      
	  , @ParamDefinition                     NVARCHAR(500)
      , @ErrorMessage                        NVARCHAR(4000)
      , @ErrorSeverity                       INT           = 18
      , @ErrorState                          INT
      
	  , @CountSelectedTables                 INT           = 0
      , @CountFKFound                        INT           = 0
      , @CountFKDropped                      INT           = 0
      , @CountFKRecreated                    INT           = 0
      , @CountSchBvFound                     INT           = 0
      , @CountSchBvDropped                   INT           = 0
      , @CountSchBvRecreated                 INT           = 0
      , @CountCDCFound						 INT		   = 0
	  , @CountCDCDisabled					 INT		   = 0
	  , @CountCDCReenabled					 INT		   = 0
	  , @CountTablesTruncated				 INT		   = 0
	  
	  , @CountSchBvReferencedObjectId        INT           = 0
      , @CountIsReferencedByFk               INT           = 0
      , @CountIsReferencedBySchBv            INT           = 0
      , @CountFKObjectIdTrgt                 INT           = 0
      
	  , @level0type                          VARCHAR(128)
      , @level0name                          sysname
      , @level1type                          VARCHAR(128)
      , @level1name                          sysname
      , @crlf                                CHAR(32)      = CONCAT(CHAR(13), CHAR(10))
      , @UnionAll                            VARCHAR(32)   = CONCAT(CHAR(10), 'UNION ALL', CHAR(10))

	  , @DateTimeStart						DATETIME
	  , @DateTimeStop						DATETIME
	  , @SecondsDuration					INT


	  
DROP TABLE IF EXISTS [#SelectedTables]
CREATE TABLE [#SelectedTables]
(
    [Id]					INT			  PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [SchemaID]				INT			  NOT NULL
  , [ObjectID]				INT			  NOT NULL
  , [SchemaName]			sysname		  NOT NULL
  , [TableName]				sysname		  NOT NULL
  , [IsReferencedByFk]		BIT			  NULL
  , [IsReferencedBySchBv]	BIT			  NULL
  , [IsCDCEnabled]			BIT			  NULL
  , [CDC_capture_instance]	SYSNAME		  NULL	   
  , [CDC_role_name]			SYSNAME		  NULL
  , [CDC_filegroup_name]	SYSNAME		  NULL
  , [RowCountBefore]		BIGINT		  NULL
  , [RowCountAfter]			BIGINT		  NULL
  , [IsTruncated]			BIT			  NULL
  , [ErrorMessage]			NVARCHAR(MAX) NULL
)

DROP TABLE IF EXISTS [#ForeignKeyConstraintDefinitions]
CREATE TABLE [#ForeignKeyConstraintDefinitions]
(
    [Id]                        INT            PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ForeignKeyId]              INT            UNIQUE NOT NULL
  , [ForeignKeyName]            SYSNAME        NOT NULL
  , [ObjectIdTrgt]				INT			   NOT NULL
  , [SchemaNameTrgt]			SYSNAME		   NOT NULL
  , [TableNameTrgt]				SYSNAME		   NOT NULL
  , [DropConstraintCommand]     NVARCHAR(MAX)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
  , [RecreateConstraintCommand] NVARCHAR(MAX)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
  , [ErrorMessage]				NVARCHAR(MAX) NULL
)

DROP TABLE IF EXISTS [#TableRowCounts]
CREATE TABLE [#TableRowCounts]
(
    [Id]        INT          PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ObjectID]  INT          UNIQUE NOT NULL
  , [TableName] VARCHAR(256) NOT NULL
  , [RowCount]  BIGINT       NOT NULL
  /*, INDEX [#IX_TableRowCounts_GtZ]([RowCount]) WHERE [RowCount] > 0  -- does not help, select does a full scan anyway */
)

DROP TABLE IF EXISTS [#SchemaBoundViews]
CREATE TABLE [#SchemaBoundViews]
(
    [Id]                      INT           PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ReferencingObjectId]     INT           UNIQUE NOT NULL
  , [ReferencingObjectSchema] NVARCHAR(128) NOT NULL
  , [ReferencingObjectName]   NVARCHAR(128) NOT NULL
  , [DropViewCommand]		  NVARCHAR(MAX) NOT NULL
  , [RecreateViewCommand]     NVARCHAR(MAX) NOT NULL
  , [@level0type]             VARCHAR(128)  NULL
  , [@level0name]             SYSNAME       NULL
  , [@level1type]             VARCHAR(128)  NULL
  , [@level1name]             SYSNAME       NULL
  , [XtdProperties]			  NVARCHAR(MAX) NULL
  , [ErrorMessage]			  NVARCHAR(MAX) NULL
)

DROP TABLE IF EXISTS [#SbvToSelTablesLink]
CREATE TABLE [#SbvToSelTablesLink] 
( 
  [ReferencingObjectId] INT NOT NULL
, [ReferncedObjectId] INT NOT NULL 
)

/* ########################################################## COLLECTING METADATA: ########################################################### */

PRINT('--------------------------------------- COLLECTING [#SelectedTables]: ------------------------------------------')
SET @StartSearchSch = 0
SET @DelimiterPosSch = 0
IF (@TruncateAllTablesPerDB <> 1)
BEGIN
    WHILE CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + 1) > 0
    BEGIN
        SET @DelimiterPosSch = CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + 1) - @StartSearchSch
        SET @SchemaName = SUBSTRING(@SchemaNames, @StartSearchSch, @DelimiterPosSch)
        SET @SchemaId = NULL;

        SET @SqlSchemaId = CONCAT('SELECT @_SchemaId = schema_id FROM [', DB_NAME(), '].sys.schemas WHERE name = ''', @SchemaName, '''');			  
		SET @ParamDefinition = N'@_SchemaName SYSNAME, @_SchemaId INT OUTPUT';			  
  
	EXEC sp_executesql @SqlSchemaId, @ParamDefinition, @_SchemaName = @SchemaName, @_SchemaId = @SchemaId OUTPUT;

        IF (@SchemaId IS NOT NULL)
           BEGIN
               SET @StartSearchTbl = 0
               SET @DelimiterPosTbl = 0
               
               WHILE CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + 1) > 0
               BEGIN
                   SET @DelimiterPosTbl = CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + 1) - @StartSearchTbl
                   SET @TableName = SUBSTRING(@TableNames, @StartSearchTbl, @DelimiterPosTbl)
                   
				   --PRINT('Getting OBJECT_ID([' + @SchemaName + '].[' + @TableName + '])')
                   SET @ObjectId = NULL;
                   SET @ObjectId = OBJECT_ID('[' + @SchemaName + '].[' + @TableName + ']');
 
				   IF (@ObjectId IS NOT NULL)
                   BEGIN
                       INSERT INTO [#SelectedTables] ( 
                                   [SchemaID]
                                  ,[ObjectID] 
                                  ,[SchemaName]             
                                  ,[TableName]
								  ,[IsTruncated]
                       )
                       VALUES (
                                   @SchemaId
                                  ,@ObjectId
                                  ,@SchemaName
                                  ,@TableName
								  ,0
                       )
                   END
                   SET @StartSearchTbl = CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + @DelimiterPosTbl) + 1
               END
           END
        SET @StartSearchSch = CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + @DelimiterPosSch) + 1
    END
END
ELSE
BEGIN
        PRINT(CONCAT(N'@TruncateAllTablesPerDB = 1 so ignoring list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames
				   , N'] specified, collecting all non-system tables in the database: [', DB_NAME(DB_ID()), N'].'));
		
		INSERT INTO [#SelectedTables] ( 
                    [SchemaID]
                   ,[ObjectID] 
                   ,[SchemaName]             
                   ,[TableName]
				   ,[IsTruncated]
        )
        SELECT  SCHEMA_ID(TABLE_SCHEMA), OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), TABLE_SCHEMA, TABLE_NAME, 0
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE' AND [TABLE_SCHEMA] NOT IN ('cdc', 'sys')
END
PRINT('--------------------------------------- END OF COLLECTING [#SelectedTables] ------------------------------------')

IF NOT EXISTS (SELECT 1 FROM [#SelectedTables])
BEGIN
    BEGIN
	SET @ErrorMessage = CONCAT('Could not find any objects specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames, N'] in the database: [', DB_NAME(DB_ID()), N'].');			
	GOTO ERROR
    END
END
ELSE
BEGIN
	BEGIN TRANSACTION

	SELECT @CountSelectedTables = COUNT(1) FROM [#SelectedTables]
	PRINT(CONCAT('Populated [#SelectedTables] with: ', @CountSelectedTables, ' Records'))
	SELECT @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

	PRINT('--------------------------------------- UPDATING [RowCountBefore] OF [#SelectedTables] BEFORE TRUNCATE: --------')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT		
			  @SqlTableCounts = 
			  CASE WHEN @SqlEngineVersion < 14 
			  /* For SQL Versions older than 14 (2017) use FOR XML PATH instead of STRING_AGG(): */
			  THEN
					STUFF((
					SELECT @UnionAll + ' SELECT '
					    + CAST([ObjectID] AS NVARCHAR(MAX)) + ' AS [ObjectID], '
					    + '''' + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					    + ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					    + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					FROM [#SelectedTables]
					WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, LEN(@UnionAll), '')
			  ELSE
			  /* For SQL Versions 14+ (2017+) use STRING_AGG(): */
					STRING_AGG(CONCAT('SELECT '
					, CAST([ObjectID] AS NVARCHAR(MAX)), ' AS [ObjectID], '
					, '''', CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					, ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					, CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))), @UnionAll)
			  END
			  
		FROM  [#SelectedTables]
		WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)

		SET @SqlTableCounts = CONCAT(N'INSERT INTO [#TableRowCounts] ([ObjectID], [TableName], [RowCount])', @SqlTableCounts)

		--SET @SqlTableCounts = CONCAT('SimulatedSyntaxError_', @SqlTableCounts)
		EXEC sys.sp_executesql @SqlTableCounts;
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTableCounts);			
			GOTO ERROR
		END
		SELECT @LineId = @LineId + 1 + @BatchSize;
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
		BEGIN
			SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
		END
	END

	UPDATE [st]
	SET    [st].[RowCountBefore] = [trc].[RowCount]
	FROM   [#SelectedTables] AS [st]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [st].[ObjectID]

	PRINT('--------------------------------------- POPULATING [#ForeignKeyConstraintDefinitions]: -------------------------')

	; WITH [cte] AS (
	SELECT          
					[ForeignKeyId]				= [fk].object_id                                                                                  
	               ,[ForeignKeyName]			= [fk].name                                                                                       
	               ,[SchemaNameSrc]				= [SchSrc].[SchemaName]                                                                         
	               ,[TableNameSrc]				= (SELECT (OBJECT_NAME([fkc].parent_object_id)))                                                
	               ,[ColumnIdSrc]				= [fkc].parent_column_id                                                                        
	               ,[ColumnNameSrc]				= [ColSrc].name                                                                                 
	               ,[SchemaNameTrgt]         	= [SchTgt].[SchemaName]                                                                         
	               ,[TableNameTrgt]				= (SELECT (OBJECT_NAME([fkc].referenced_object_id)))                                            
	               ,[ColumnIdTrgt]				= [fkc].referenced_column_id                                                                    
	               ,[ColumnNameTrgt]			= [ColTgt].name                                                                                 
	               ,[SchemaIdTrgt]				= [SchTgt].[SchemaId]                                                                           
	               ,[DeleteReferentialAction]	= [fk].[delete_referential_action]															    
	               ,[UpdateReferentialAction]	= [fk].[update_referential_action]															    
	               ,[ObjectIdTrgt]				= OBJECT_ID('[' + [SchTgt].[SchemaName] + '].[' + OBJECT_NAME([fkc].referenced_object_id) + ']')
	FROM            sys.foreign_keys                                               AS [fk]
	CROSS APPLY     (
	                    SELECT  
	                            [fkc].parent_column_id,
	                            [fkc].parent_object_id,
	                            [fkc].referenced_object_id,
	                            [fkc].referenced_column_id
	                    FROM    sys.foreign_key_columns                            AS [fkc] 
	                    WHERE   1 = 1
	                    AND     fk.parent_object_id = [fkc].parent_object_id 
	                    AND     fk.referenced_object_id = [fkc].referenced_object_id
	                    AND     fk.object_id = [fkc].constraint_object_id
	                )                                                              AS [fkc]
	CROSS APPLY     (
	                    SELECT     [ss].name                                       AS [SchemaName]
	                    FROM       sys.objects                                     AS [so]
	                    INNER JOIN sys.schemas                                     AS [ss] ON [ss].schema_id = [so].schema_id
	                    WHERE      [so].object_id = [fkc].parent_object_id
	                )                                                              AS [SchSrc]
	CROSS APPLY     (
	                    SELECT [sc].name      
	                    FROM   sys.columns                                         AS [sc] 
	                    WHERE  [sc].object_id = [fk].[parent_object_id] 
	                    AND    [sc].column_id = [fkc].[parent_column_id]
	                )                                                              AS [ColSrc]
	CROSS APPLY     (
	                    SELECT     [ss].schema_id                                  AS [SchemaId]
	                              ,[ss].name                                       AS [SchemaName]
	                    FROM       sys.objects                                     AS [so]
	                    INNER JOIN sys.schemas                                     AS [ss] ON [ss].schema_id = [so].schema_id
	                    WHERE      [so].object_id = [fkc].[referenced_object_id]
	                )                                                              AS [SchTgt]
	CROSS APPLY     (
	                    SELECT [sc].name      
	                    FROM   sys.columns                                         AS [sc] 
	                    WHERE  [sc].object_id = [fk].[referenced_object_id] 
	                    AND    [sc].column_id = [fkc].[referenced_column_id]
	                )                                                              AS [ColTgt]
	INNER JOIN      [#SelectedTables]											   AS [st] 
	ON              [st].[SchemaID] = [SchTgt].[SchemaId] 
	/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one: */
	/* AND             [st].[ObjectID] = OBJECT_ID(QUOTENAME([SchSrc].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id]))) */
	AND             [st].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))		
	)
	INSERT INTO   [#ForeignKeyConstraintDefinitions](
	              [ForeignKeyId]
				, [ForeignKeyName]
				, [ObjectIdTrgt]
				, [SchemaNameTrgt]
				, [TableNameTrgt]	
	            , [DropConstraintCommand]     
	            , [RecreateConstraintCommand])
	SELECT         
	             [cte].[ForeignKeyId],
				 [cte].[ForeignKeyName],
				 [cte].[ObjectIdTrgt],
				 [cte].[SchemaNameTrgt],
				 [cte].[TableNameTrgt],	
	             [DropConstraintCommand] = 
	                    'ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc]) + '.' + QUOTENAME([cte].[TableNameSrc])+' DROP CONSTRAINT ' + QUOTENAME([cte].[ForeignKeyName]) + ';',        
	             
	             [RecreateConstraintCommand] = 
	             CONCAT('ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc]) + '.'+ QUOTENAME([cte].[TableNameSrc])+' WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME([cte].[ForeignKeyName]) + ' ',
	             CASE 
	             WHEN @SqlEngineVersion < 14 
	             /* For SQL Versions older than 14 (2017) use FOR XML PATH for all multi-column constraints: */
	             THEN   'FOREIGN KEY ('+ STUFF((SELECT   ', ' + QUOTENAME([t].[ColumnNameSrc])
	                                            FROM      [cte] AS [t]
	                                            WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                            ORDER BY  [t].[ColumnIdTrgt] --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
	                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' ) ' +
	                    'REFERENCES '  + QUOTENAME([cte].[SchemaNameTrgt])+'.'+ QUOTENAME([cte].[TableNameTrgt])+
	                              ' (' + STUFF((SELECT   ', ' + QUOTENAME([t].[ColumnNameTrgt])
	                                            FROM      [cte] AS [t]
	                                            WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                            ORDER BY  [t].[ColumnIdTrgt] --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
	                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' )'                 
	             ELSE   
	                    /* For SQL Versions 2017+ use STRING_AGG for all multi-column constraints: */                  
	                    'FOREIGN KEY ('+ STRING_AGG(QUOTENAME([cte].[ColumnNameSrc]), ', ') WITHIN GROUP (ORDER BY [cte].[ColumnIdTrgt]) +') '+
	                    'REFERENCES '  + QUOTENAME([cte].[SchemaNameTrgt])+'.'+ QUOTENAME([cte].[TableNameTrgt])+' ('+ STRING_AGG(QUOTENAME([cte].[ColumnNameTrgt]), ', ') + ')'             
	             END,   
	             CASE
	                 WHEN [cte].[DeleteReferentialAction] = 1 THEN ' ON DELETE CASCADE '
	                 WHEN [cte].[DeleteReferentialAction] = 2 THEN ' ON DELETE SET NULL '
	                 WHEN [cte].[DeleteReferentialAction] = 3 THEN ' ON DELETE SET DEFAULT '
	                 ELSE ''
	             END,
	             CASE
	                 WHEN [cte].[UpdateReferentialAction] = 1 THEN ' ON UPDATE CASCADE '
	                 WHEN [cte].[UpdateReferentialAction] = 2 THEN ' ON UPDATE SET NULL '
	                 WHEN [cte].[UpdateReferentialAction] = 3 THEN ' ON UPDATE SET DEFAULT '
	                 ELSE ''
	             END,
	             CHAR(13)+ 'ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc])+'.'+ QUOTENAME([cte].[TableNameSrc])+' CHECK CONSTRAINT '+ QUOTENAME([cte].[ForeignKeyName])+';')
	FROM         [cte]
	GROUP BY     
	             [cte].[ForeignKeyId]
	            ,[cte].[SchemaNameSrc]
	            ,[cte].[TableNameSrc]
	            ,[cte].[ForeignKeyName]
				,[cte].[ObjectIdTrgt]
	            ,[cte].[SchemaNameTrgt]
	            ,[cte].[TableNameTrgt]
	            ,[cte].[DeleteReferentialAction]
	            ,[cte].[UpdateReferentialAction]
	ORDER BY     [cte].[TableNameSrc]
	
	IF NOT EXISTS (SELECT 1 FROM [#ForeignKeyConstraintDefinitions])
	BEGIN
	    PRINT(CONCAT(N'Could not find any foreign keys referencing the tables specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames, N'] in the database: [', DB_NAME(DB_ID()), N'].'));
		
		UPDATE [st]
		SET    [st].[IsReferencedByFk] = 0
		FROM   [#SelectedTables] AS [st]
	END
	ELSE 
	BEGIN
    
		SELECT @CountFKFound = COUNT(1) FROM [#ForeignKeyConstraintDefinitions]
		PRINT(CONCAT('Populated [#ForeignKeyConstraintDefinitions] with: ', @CountFKFound, ' Records'))

		UPDATE		[st]
		SET			[st].[IsReferencedByFk] = CASE WHEN [fkc].[ObjectIdTrgt] IS NOT NULL THEN 1 ELSE 0 END
		FROM		[#SelectedTables] AS [st]
		LEFT JOIN   [#ForeignKeyConstraintDefinitions] AS [fkc] ON [st].[ObjectID] = [fkc].[ObjectIdTrgt]

		SELECT @CountFKObjectIdTrgt = COUNT(DISTINCT [ObjectIdTrgt]) FROM [#ForeignKeyConstraintDefinitions]
		SELECT @CountIsReferencedByFk = COUNT(1) FROM [#SelectedTables] WHERE [IsReferencedByFk] = 1;
		
		--SET @CountFKObjectIdTrgt = @CountFKObjectIdTrgt + 1
		IF (@CountFKObjectIdTrgt <> @CountIsReferencedByFk)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Distinct Count of [#ForeignKeyConstraintDefinitions].[ObjectIdTrgt]: ', @CountFKObjectIdTrgt
									, ' does not match the number of [IsReferencedByFk] flags in [#SelectedTables]: ', @CountIsReferencedByFk);
			GOTO ERROR
		END
		ELSE
		BEGIN
			PRINT(CONCAT('Distinct Count of [#ForeignKeyConstraintDefinitions].[ObjectIdTrgt]: ', @CountFKObjectIdTrgt
					  , ' matches the number of [IsReferencedByFk] flags in [#SelectedTables]: ', @CountIsReferencedByFk));
		END
	END

	PRINT('--------------------------------------- POPULATING [#SchemaBoundViews]: ----------------------------------------')
	
	TRUNCATE TABLE [#SchemaBoundViews]
	INSERT INTO [#SchemaBoundViews]
	    (
	        [ReferencingObjectId]
	      , [ReferencingObjectSchema]
	      , [ReferencingObjectName]
	      , [DropViewCommand]
	      , [RecreateViewCommand]
	    )	 
	SELECT  DISTINCT 
		   [sed].[referencing_id]					AS [ReferencingObjectId]
		 , SCHEMA_NAME([ss].[schema_id])			AS [ReferencingObjectSchema]
		 , OBJECT_NAME([vid].[object_id])			AS [ReferencingObjectName]
		 , CONCAT('DROP VIEW ', QUOTENAME(SCHEMA_NAME([ss].[schema_id])), '.', QUOTENAME(OBJECT_NAME([vid].[object_id]))) AS [DropViewCommand]
		 , [sqm].[definition]						AS [RecreateViewCommand]
	FROM   [sys].[sql_expression_dependencies]		AS [sed]
	JOIN   [sys].[objects]							AS [vid]
		ON [sed].[referencing_id] = [vid].[object_id]
	JOIN   [sys].[schemas]							AS [ss]
	    ON [ss].[schema_id] = [vid].[schema_id]
	JOIN   [sys].[sql_modules]						AS [sqm]
		ON [sqm].[object_id] = [vid].[object_id]
	JOIN   [#SelectedTables]						AS [st]
		ON [sed].[referenced_id] = [st].[ObjectID]
	WHERE  [vid].[type_desc] = 'VIEW'
	AND    [sqm].[is_schema_bound] = 1
	
	UPDATE  [sbv]
	SET 
		    [sbv].[@level0type] = [Xtp].[@level0type]
		  , [sbv].[@level0name] = [Xtp].[@level0name]
		  , [sbv].[@level1type] = [Xtp].[@level1type]
		  , [sbv].[@level1name] = [Xtp].[@level1name]
	FROM    [#SchemaBoundViews] AS [sbv]
			OUTER APPLY (
							SELECT DISTINCT
							       'SCHEMA'			   AS [@level0type]
							     , [sch].[name]		   AS [@level0name]
							     , [obj].[type_desc]   AS [@level1type]
							     , [obj].[name]		   AS [@level1name]
							FROM [sys].[objects] [obj]
							INNER JOIN [sys].[schemas] AS [sch]
							    ON [obj].[schema_id]	= [sch].[schema_id]
							INNER JOIN [sys].[columns] AS [col]
							    ON [obj].[object_id]	= [col].[object_id]
							WHERE [obj].[object_id]		= [sbv].[ReferencingObjectId]
						) AS [Xtp]

	IF NOT EXISTS (SELECT 1 FROM [#SchemaBoundViews])
	BEGIN
	    PRINT(CONCAT(N'Could not find any [#SchemaBoundViews] referencing the tables specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames + N'] in the database: [', DB_NAME(DB_ID()), N'].'));
		UPDATE [st]
		SET    [st].[IsReferencedBySchBv] = 0
		FROM   [#SelectedTables] AS [st]
	END
	ELSE 
	BEGIN
		SELECT @CountSchBvFound = COUNT(1) FROM [#SchemaBoundViews]
		PRINT(CONCAT('Populated [#SchemaBoundViews] with: ', @CountSchBvFound, ' Records.'))

		TRUNCATE TABLE [#SbvToSelTablesLink]
		INSERT INTO [#SbvToSelTablesLink] ([ReferencingObjectId], [ReferncedObjectId])
   	    SELECT DISTINCT 
   			    [sbv].[ReferencingObjectId]
   			  , [sed].[referenced_id] AS [ReferncedObjectId]
   	    FROM	[#SchemaBoundViews]	 AS [sbv]
   	    JOIN	[sys].[sql_expression_dependencies] AS [sed] 
   	    ON		[sed].[referencing_id] = [sbv].[ReferencingObjectId]
		JOIN	[#SelectedTables] AS [st]
		ON		[st].[ObjectID] = [sed].[referenced_id]
			
		UPDATE		[st]
		SET			[st].[IsReferencedBySchBv] = CASE WHEN [sbvcr].[ReferncedObjectId] IS NOT NULL THEN 1 ELSE 0 END
		FROM		[#SelectedTables] AS [st]
		LEFT JOIN   [#SbvToSelTablesLink] AS [sbvcr] ON [sbvcr].[ReferncedObjectId] = [st].[ObjectID]

		SELECT @CountSchBvReferencedObjectId = COUNT(DISTINCT [ReferncedObjectId]) FROM [#SbvToSelTablesLink]
		SELECT @CountIsReferencedBySchBv	 = COUNT(1) FROM [#SelectedTables] WHERE [IsReferencedBySchBv] = 1;

		--SET @CountSchBvReferencedObjectId = @CountSchBvReferencedObjectId + 1
		--SET @CountIsReferencedBySchBv = @CountIsReferencedBySchBv + 1
		IF (@CountSchBvReferencedObjectId <> @CountIsReferencedBySchBv)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Number of DISTINCT [ReferencedObjectId] in Schema-Bound Views: ', @CountSchBvReferencedObjectId
									, ' does not match the Number of Updated [#SelectedTables].[IsReferencedBySchBv] flag: ', @CountIsReferencedBySchBv);              
			GOTO ERROR
		END
		ELSE
		BEGIN
			PRINT(CONCAT('Number of DISTINCT [ReferencedObjectId] in Schema-Bound Views: ', @CountSchBvReferencedObjectId, ' matches the Number of Updated [#SelectedTables].[IsReferencedBySchBv] flag: ', @CountIsReferencedBySchBv));
		END

		PRINT('--------------------------------------- UPDATING [XtdProperties] of [#SchemaBoundViews]: -----------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
		WHILE (@LineId <= @LineIdMax)
		BEGIN
		    SELECT @level0type = [@level0type]
		         , @level0name = [@level0name]
		         , @level1type = [@level1type]
		         , @level1name = [@level1name]
		    FROM [#SchemaBoundViews]
		    WHERE [Id] = @LineId
		
			SELECT @SqlXtndProperties = STRING_AGG((CONCAT(
				  'EXEC [sys].[sp_addextendedproperty] @name = '''
				 , [name]
				 , ''', @value = '''
				 , CONVERT(NVARCHAR(MAX), [value])
				 , ''', @level0type = '''
				 , @level0type
				 , ''', @level0name = '''
				 , @level0name
				 , ''', @level1type = '''
				 , @level1type
				 , ''', @level1name = '''
				 , @level1name
				 , ''';'
				 )), @crlf)
			FROM [sys].fn_listextendedproperty(NULL, @level0type, @level0name, @level1type, @level1name, NULL, NULL)
							
			IF (@SqlXtndProperties IS NOT NULL)
			BEGIN
				UPDATE [#SchemaBoundViews]
				SET [XtdProperties] = @SqlXtndProperties
				WHERE [Id] = @LineId    
			END
		
			SET @SqlXtndProperties = NULL;
			SELECT @LineId = @LineId + 1;
			IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
			BEGIN
				SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
				PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
			END
		END			
	END
	
	PRINT('--------------------------------------- END OF POPULATING [#SchemaBoundViews]: ---------------------------------')

	IF EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_SCHEMA] = 'cdc' AND [TABLE_NAME] = 'change_tables')
	BEGIN
		PRINT('--------------------------------------- UPDATING [IsCDCEnabled] flag of [#SelectedTables]: ---------------------')
		
		UPDATE [st]
		SET		
				   [st].[IsCDCEnabled]			= CASE WHEN [cdc].[source_object_id] IS NOT NULL THEN 1 ELSE 0 END
				 , [st].[CDC_capture_instance]	= [capture_instance]	   
				 , [st].[CDC_role_name]			= [role_name]
				 , [st].[CDC_filegroup_name]	= [filegroup_name]
		FROM	   [#SelectedTables]			AS [st]
		LEFT JOIN  [cdc].[change_tables]		AS [cdc] ON [st].[ObjectID] = [cdc].[source_object_id]

		IF NOT EXISTS (SELECT 1 FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1)
		BEGIN
			PRINT(CONCAT(N'Could not find any records in [cdc].[change_tables] matching the tables specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames + N'] in the database: [', DB_NAME(DB_ID()), N'].'));
			SELECT @CountCDCFound = 0 
		END
		ELSE
        BEGIN
			SELECT @CountCDCFound = COUNT(1) FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1
		END

		PRINT('--------------------------------------- END OF UPDATING [IsCDCEnabled] flag of [#SelectedTables] ---------------')		
	END

/* ########################################################## DROPPING AND DISABLING: ######################################################## */

	IF (@CountFKFound > 0)
	BEGIN
		PRINT('--------------------------------------- DROPPING FK CONSTRAINTS: -----------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlDropConstraint = [DropConstraintCommand]
			FROM   [#ForeignKeyConstraintDefinitions]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlDropConstraint;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropConstraint);
				GOTO ERROR
			END
			ELSE 
			BEGIN
				SELECT @LineId = @LineId + 1;
				SELECT @CountFKDropped = @CountFKDropped + 1
				IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
				BEGIN
					SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
					PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
				END        
			END
		END
		IF (@CountFKFound <> @CountFKDropped)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Number of FK Constraints Found: ', @CountFKFound
									, ' does not match the Number of FK Constraints dropped: ', @CountFKDropped);              
			GOTO ERROR
		END
		ELSE
		BEGIN			
			PRINT(CONCAT('Successfully dropped: ', COALESCE(@CountFKDropped, 0), ' FK Constraints (matches the number of FK Constraints Found).'))		
		END
		
		PRINT('--------------------------------------- END OF DROPPING FK CONSTRAINTS -----------------------------------------')
	END


	IF (@CountSchBvFound > 0)
	BEGIN
		PRINT('--------------------------------------- DROPPING SCHEMA-BOUND VIEWS: -------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlDropView = [DropViewCommand]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlDropView;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropView);
				GOTO ERROR
			END
			SELECT @LineId = @LineId + 1;
			SELECT @CountSchBvDropped = @CountSchBvDropped + 1
		END
		IF (@CountSchBvFound <> @CountSchBvDropped)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Number of Schema-Bound Views Found: ', @CountSchBvFound
									, ' does not match the Number of Schema-Bound Views dropped: ', @CountSchBvDropped);              
			GOTO ERROR
		END
		ELSE
		BEGIN			
			PRINT(CONCAT('Successfully dropped: ', COALESCE(@CountSchBvDropped, 0), ' Schema-Bound Views (matches the number of Schema-Bound Views Found).'))		
		END

		PRINT('--------------------------------------- END OF DROPPING SCHEMA-BOUND VIEWS -------------------------------------')
	END

	IF (@CountCDCFound > 0)
	BEGIN
		PRINT('--------------------------------------- DISABLING CDC: ---------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1;
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT
				   @CDC_source_schema	 = 	[SchemaName]	
				 , @CDC_source_name		 = 	[TableName]		
				 , @CDC_capture_instance = 	[CDC_capture_instance]
			
			FROM   [#SelectedTables]
			WHERE  [Id] = @LineId

			
			EXECUTE sys.sp_cdc_disable_table
			@source_schema			= @CDC_source_schema		
		  , @source_name			= @CDC_source_name		
		  , @capture_instance		= @CDC_capture_instance	
						
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing sys.sp_cdc_disable_table with parameters @source_schema: '
											, @CDC_source_schema, ' @source_name: ', @CDC_source_name, ' @capture_instance: ', @CDC_capture_instance);
				GOTO ERROR																								  		
			END
			ELSE 
			BEGIN
				SELECT @LineId = MIN([Id]) FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1 AND [Id] > @LineId;
				SELECT @CountCDCDisabled = @CountCDCDisabled + 1
				IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
				BEGIN
					SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
					PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
				END        
			END			
		END
		IF (@CountCDCFound <> @CountCDCDisabled)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Number of CDC-Enabled Tables Found: ', @CountCDCFound
									, ' does not match the Number of CDC-Enabled Tables Disabled: ', @CountCDCDisabled);              
			GOTO ERROR
		END
		ELSE
		BEGIN						
			PRINT(CONCAT('Successfully disabled CDC for : ', COALESCE(@CountCDCDisabled, 0), ' Tables (matches the number of CDC-Enabled Tables Found).'))
		END
		
		PRINT('--------------------------------------- END OF DISABLING CDC ---------------------------------------------------')
	END

/* ########################################################## TRUNCATING TABLES: ############################################################# */

	IF (@CountSelectedTables > 0)
	BEGIN
		PRINT('--------------------------------------- TRUNCATING TABLES: -----------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN

			SELECT @SqlTruncateTable = CONCAT('IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.[TABLES] WHERE [TABLE_SCHEMA] = '''
											, [SchemaName], '''', ' AND [TABLE_NAME] = ''', [TableName], ''') TRUNCATE TABLE ['
											, [SchemaName], '].[', [TableName], '];')
			FROM   [#SelectedTables]
			WHERE  [Id] = @LineId
			
			EXEC sys.sp_executesql @SqlTruncateTable;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTruncateTable);
				GOTO ERROR																								  		
			END
			ELSE 
			BEGIN
				UPDATE [#SelectedTables] SET [IsTruncated] = 1 WHERE [Id] = @LineId
				SELECT @LineId = @LineId + 1;
				SELECT @CountTablesTruncated = @CountTablesTruncated + 1

				SELECT @SqlUpdateStatistics = CONCAT('UPDATE STATISTICS [', [SchemaName], '].[', [TableName], '];')
				FROM   [#SelectedTables]
				WHERE  [Id] = @LineId

				EXEC sys.sp_executesql @SqlUpdateStatistics;
				IF (@@ERROR <> 0)
				BEGIN
					ROLLBACK TRANSACTION
					SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlUpdateStatistics);
					GOTO ERROR																								  		
				END

				IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
				BEGIN
					SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
					PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
				END        
			END
		END
		IF (@CountTablesTruncated <> @CountSelectedTables)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Number of Tables truncated: ', @CountTablesTruncated
									, ' does not match the Number of Tables Selected: ', @CountSelectedTables);              
			GOTO ERROR
		END
		ELSE
		BEGIN						
			PRINT(CONCAT('Successfully truncated : ', COALESCE(@CountTablesTruncated, 0), ' Tables (matches the number of Tables Selected).'))
		END
		
		PRINT('--------------------------------------- END OF TRUNCATING TABLES -----------------------------------------------')
	END

/* ########################################################## RECREATING AND RE-ENABLING: #################################################### */

	SET XACT_ABORT OFF; /* !!! without SET XACT_ABORT OFF here all errors below break the execution even with TRY-CATCH blocks */

	IF (@CountCDCFound > 0) AND (@ReenableCDC = 1)
	BEGIN
		PRINT('--------------------------------------- RE-ENABLING CDC: -------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1;
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT
				   @CDC_source_schema	 = 	[SchemaName]	
				 , @CDC_source_name		 = 	[TableName]		
				 , @CDC_role_name		 =  [CDC_role_name]		
				 , @CDC_filegroup_name	 =  [CDC_filegroup_name]			
			FROM   [#SelectedTables]
			WHERE  [Id] = @LineId

			
			BEGIN TRY
				EXECUTE sys.sp_cdc_enable_table
						@source_schema		= @CDC_source_schema	
					  , @source_name		= @CDC_source_name		
					  , @role_name			= @CDC_role_name		
					  , @filegroup_name		= @CDC_filegroup_name            
			END TRY
			BEGIN CATCH
				SET @ErrorMessage = ERROR_MESSAGE()
				UPDATE [#SelectedTables] SET [ErrorMessage] = @ErrorMessage WHERE [Id] = @LineId
				PRINT(@ErrorMessage)
			END CATCH

			SELECT @LineId = MIN([Id]) FROM [#SelectedTables] WHERE [IsCDCEnabled] = 1 AND [Id] > @LineId;
			SELECT @CountCDCReenabled = @CountCDCReenabled + 1
			IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
			BEGIN
				SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
				PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
			END		
		END
		IF (@CountCDCReenabled <> @CountCDCDisabled)
		BEGIN
			PRINT(CONCAT('Number of CDC-Re-Enabled Tables: ', @CountCDCReenabled
									, ' does not match the Number of CDC-Enabled Tables Disabled: ', @CountCDCDisabled));
		END
		ELSE
		BEGIN						
			PRINT(CONCAT('Successfully re-enabled CDC for : ', COALESCE(@CountCDCReenabled, 0), ' Tables (matches the number of CDC-Enabled Tables Disabled).'))
		END
		
		PRINT('--------------------------------------- END OF RE-ENABLING CDC -------------------------------------------------')
	END

	IF (@CountSchBvFound > 0)
	BEGIN
		PRINT('--------------------------------------- RECREATING SCHEMA-BOUND VIEWS: -----------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlRecreateView = [RecreateViewCommand]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId
			
			BEGIN TRY
				EXEC sys.sp_executesql @SqlRecreateView;           
			END TRY
			BEGIN CATCH
				SET @ErrorMessage = ERROR_MESSAGE()
				UPDATE [#SchemaBoundViews] SET [ErrorMessage] = @ErrorMessage WHERE [Id] = @LineId
				PRINT(@ErrorMessage)
			END CATCH			
			
			SELECT @SqlXtndProperties = [XtdProperties]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId

			IF (@SqlXtndProperties IS NOT NULL)
			BEGIN TRY
				EXEC sys.sp_executesql @SqlXtndProperties;           
			END TRY
			BEGIN CATCH
				SET @ErrorMessage = ERROR_MESSAGE()
				UPDATE [#SchemaBoundViews] SET [ErrorMessage] = CONCAT([ErrorMessage], '; ', @ErrorMessage) WHERE [Id] = @LineId
				PRINT(@ErrorMessage)
			END CATCH

			SET @SqlXtndProperties = NULL;

			SELECT @LineId = @LineId + 1;
			SELECT @CountSchBvRecreated = @CountSchBvRecreated + 1
		END
		IF (@CountSchBvRecreated <> @CountSchBvDropped)
		BEGIN
			PRINT(CONCAT('Rolling back transaction - Number of Schema-Bound Views Recreated: ', @CountSchBvRecreated
									, ' does not match the Number of Schema-Bound Views dropped: ', @CountSchBvDropped));
		END
		ELSE
		BEGIN			
			PRINT(CONCAT('Successfully Recreated: ', COALESCE(@CountSchBvRecreated, 0), ' Schema-Bound Views (matches the number of Schema-Bound Views previously Dropped).'))		
		END

		PRINT('--------------------------------------- END OF RECREATING SCHEMA-BOUND VIEWS -----------------------------------')
	END

	IF (@CountFKFound > 0)
	BEGIN
		PRINT('--------------------------------------- RECREATING FK CONSTRAINTS: ---------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlRecreateConstraint = [RecreateConstraintCommand]
			FROM   [#ForeignKeyConstraintDefinitions]
			WHERE  [Id] = @LineId

			BEGIN TRY
				EXEC sys.sp_executesql @SqlRecreateConstraint;           
			END TRY
			BEGIN CATCH
				SET @ErrorMessage = ERROR_MESSAGE()
				UPDATE [#ForeignKeyConstraintDefinitions] SET [ErrorMessage] = @ErrorMessage WHERE [Id] = @LineId
				PRINT(@ErrorMessage)
			END CATCH

			SELECT @LineId = @LineId + 1;
			SELECT @CountFKRecreated = @CountFKRecreated + 1
			IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
			BEGIN
				SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
				PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
			END
		END
		IF (@CountFKRecreated <> @CountFKDropped)
		BEGIN
			PRINT(CONCAT('Rolling back transaction - Number of FK Constraints Re-Created: ', @CountFKRecreated
									, ' does not match the Number of FK Constraints dropped: ', @CountFKDropped));
		END
		ELSE
		BEGIN			
			PRINT(CONCAT('Successfully recreated: ', COALESCE(@CountFKRecreated, 0), ' FK Constraints (matches the number of FK Constraints Dropped).'))		
		END
		
		PRINT('--------------------------------------- END OF RECREATING FK CONSTRAINTS ---------------------------------------')
	END

	PRINT('--------------------------------------- UPDATING [RowCountAfter] OF [#SelectedTables] AFTER TRUNCATE: ---------- ')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT		
			  @SqlTableCounts = 
			  CASE WHEN @SqlEngineVersion < 14 
			  /* For SQL Versions older than 14 (2017) use FOR XML PATH instead of STRING_AGG(): */
			  THEN
					STUFF((
					SELECT @UnionAll + ' SELECT '
					    + CAST([ObjectID] AS NVARCHAR(MAX)) + ' AS [ObjectID], '
					    + '''' + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					    + ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					    + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					FROM [#SelectedTables]
					WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, LEN(@UnionAll), '')
			  ELSE
			  /* For SQL Versions 14+ (2017+) use STRING_AGG(): */
					STRING_AGG(CONCAT('SELECT '
					, CAST([ObjectID] AS NVARCHAR(MAX)), ' AS [ObjectID], '
					, '''', CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					, ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					, CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))), @UnionAll)
			  END
			  
		FROM  [#SelectedTables]
		WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)

		SET @SqlTableCounts = CONCAT(N'INSERT INTO [#TableRowCounts] ([ObjectID], [TableName], [RowCount])', @SqlTableCounts)

		--SET @SqlTableCounts = CONCAT('SimulatedSyntaxError_', @SqlTableCounts)
		BEGIN TRY
			EXEC sys.sp_executesql @SqlTableCounts;           
		END TRY
		BEGIN CATCH
			SET @ErrorMessage = ERROR_MESSAGE()
			PRINT(@ErrorMessage)
		END CATCH

		SELECT @LineId = @LineId + 1 + @BatchSize;
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentProcessed
		BEGIN
			SET @PercentProcessed = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT(@PercentProcessed, ' percent processed.'))
		END
	END

	UPDATE [st]
	SET    [st].[RowCountAfter] = [trc].[RowCount]
	FROM   [#SelectedTables] AS [st]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [st].[ObjectID]
	PRINT('--------------------------------------- END OF UPDATING [RowCountAfter] OF [#SelectedTables] AFTER TRUNCATE ---- ')
	
	IF XACT_STATE() = 1
	BEGIN
		COMMIT TRANSACTION
		GOTO SUCCESS
	END
END

ERROR:
	BEGIN
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END

SUCCESS:
	BEGIN
		PRINT('--------------------------------------- PRINTING SUMMARY OUTPUT TABLE: ----------------------------------------- ')
		SELECT [Id]
             , [SchemaID]
             , [ObjectID]
             , [SchemaName]
             , [TableName]
             , [IsReferencedByFk]
             , [IsReferencedBySchBv]
             , [IsCDCEnabled]
             , [CDC_capture_instance]
             , [CDC_role_name]
             , [CDC_filegroup_name]
             , [RowCountBefore]
             , [RowCountAfter]
             , [IsTruncated]
             , [ErrorMessage] FROM [#SelectedTables] --WHERE [ErrorMessage] IS NOT NULL
		ORDER BY [RowCountBefore] DESC, [TableName]  --DESC		
		--SELECT * FROM [#ForeignKeyConstraintDefinitions]  --WHERE [ErrorMessage] IS NOT NULL
		--SELECT * FROM [#SchemaBoundViews]					--WHERE [ErrorMessage] IS NOT NULL
		IF (@ErrorMessage IS NULL) PRINT('Script completed successfully.')
	END
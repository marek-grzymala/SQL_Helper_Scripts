USE [AdventureWorks2019]
GO

/****** Object:  View [Production].[vProductAndDescription]    Script Date: 6/26/2023 11:01:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER VIEW [Production].[vProductAndDescription]
WITH SCHEMABINDING
AS
-- View (indexed or standard) to display products and product descriptions by language.
SELECT [ProductID]
     , [p].[Name]
     , [pm].[Name] AS [ProductModel]
     , [CultureID]
     , [Description]
FROM [Production].[Product] [p]
INNER JOIN [Production].[ProductModel] [pm]
    ON [p].[ProductModelID] = [pm].[ProductModelID]
INNER JOIN [Production].[ProductModelProductDescriptionCulture] [pmx]
    ON [pm].[ProductModelID] = [pmx].[ProductModelID]
INNER JOIN [Production].[ProductDescription] [pd]
    ON [pmx].[ProductDescriptionID] = [pd].[ProductDescriptionID];
GO

IF NOT EXISTS (
                  SELECT *
                  FROM [sys].fn_listextendedproperty(N'Dupa', N'SCHEMA', N'Production', N'VIEW', N'vProductAndDescription', NULL, NULL)
              )
    EXEC [sys].[sp_addextendedproperty] @name = N'Dupa'
                                      , @value = N'Dupa Jasiu'
                                      , @level0type = N'SCHEMA'
                                      , @level0name = N'Production'
                                      , @level1type = N'VIEW'
                                      , @level1name = N'vProductAndDescription'
ELSE
BEGIN
    EXEC [sys].[sp_updateextendedproperty] @name = N'Dupa'
                                         , @value = N'Dupa Jasiu'
                                         , @level0type = N'SCHEMA'
                                         , @level0name = N'Production'
                                         , @level1type = N'VIEW'
                                         , @level1name = N'vProductAndDescription'
END
GO

IF NOT EXISTS (
                  SELECT *
                  FROM [sys].fn_listextendedproperty(N'MS_Description', N'SCHEMA', N'Production', N'VIEW', N'vProductAndDescription', NULL, NULL)
              )
    EXEC [sys].[sp_addextendedproperty] @name = N'MS_Description'
                                      , @value = N'Product names and descriptions. Product descriptions are provided in multiple languages.'
                                      , @level0type = N'SCHEMA'
                                      , @level0name = N'Production'
                                      , @level1type = N'VIEW'
                                      , @level1name = N'vProductAndDescription'
ELSE
BEGIN
    EXEC [sys].[sp_updateextendedproperty] @name = N'MS_Description'
                                         , @value = N'Product names and descriptions. Product descriptions are provided in multiple languages.'
                                         , @level0type = N'SCHEMA'
                                         , @level0name = N'Production'
                                         , @level1type = N'VIEW'
                                         , @level1name = N'vProductAndDescription'
END
GO


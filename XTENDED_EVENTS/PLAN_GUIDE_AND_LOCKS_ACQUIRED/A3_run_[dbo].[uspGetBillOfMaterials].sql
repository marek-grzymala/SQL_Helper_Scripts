USE [AdventureWorks2019]
GO

DECLARE @RC INT
DECLARE @StartProductID INT = 517
DECLARE @CheckDate DATETIME = '2010-09-15 00:00:00.000'

-- TODO: Set parameter values here.

EXECUTE @RC = [dbo].[uspGetBillOfMaterials] 
   @StartProductID
  ,@CheckDate
GO



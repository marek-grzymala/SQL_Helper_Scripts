USE AdventureWorks2019
GO

-- basic serialisable range deadlock, window 1

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

BEGIN TRANSACTION

SET LOCK_TIMEOUT 300000 -- 5 minutes

SELECT * FROM Production.Product AS p WHERE ProductNumber LIKE 'H%'

-- run up to here, then switch to window 2

INSERT INTO Production.Product (Name, ProductNumber, SafetyStockLevel, ReorderPoint, StandardCost, ListPrice, DaysToManufacture, SellStartDate, SellEndDate)
VALUES ('fake1', 'HM-0002', 1, 1, 1, 1, 1, GETDATE(), GETDATE());

ROLLBACK TRANSACTION
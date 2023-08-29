USE AdventureWorks2019
GO

SET LOCK_TIMEOUT 300000


-- basic key-lookup deadlock window 2

BEGIN TRANSACTION
 UPDATE Production.Product SET ProductNumber = ProductNumber + '_ABC'
 WHERE StandardCost = 0
ROLLBACK

GO 100

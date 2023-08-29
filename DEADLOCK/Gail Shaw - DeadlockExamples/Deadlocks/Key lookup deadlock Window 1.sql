USE AdventureWorks2019
GO


SET LOCK_TIMEOUT 300000 -- 5 minutes

-- basic key-lookup deadlock window 1

--Run this then switch to window 2 and run that code

SELECT * FROM [Production].[Product] WITH (INDEX=[AK_Product_ProductNumber]) 
WHERE ProductNumber LIKE 'H%'
GO 100
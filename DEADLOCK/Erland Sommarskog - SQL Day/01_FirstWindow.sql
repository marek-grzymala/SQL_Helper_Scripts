USE Northwind
go
-- 1. Run this.
BEGIN TRANSACTION

UPDATE dbo.Orders
SET    Freight = 45
WHERE  OrderID = 10500
go
-- Leave transaction open and move to the second window.

-- 5. Update one more order. Notice that this order has also been updated in
-- the second window.
UPDATE dbo.Orders
SET    Freight = 17.23
WHERE  OrderID = 11000
go
-- 6. Both windows will be in the Exuecting state for a few seconds.
-- 7. Eventually, one of them will get a deadlock error.
-- 8. If this window completed successfully, rollback the transaction.
-- 9. Go to the other window.
ROLLBACK TRANSACTION

-- 10. Go to the other window.


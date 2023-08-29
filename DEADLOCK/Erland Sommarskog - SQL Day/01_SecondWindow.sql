USE Northwind
go
-- 2. Run this, with the transaction in the first window open.
BEGIN TRANSACTION

UPDATE dbo.Orders
SET    ShipAddress = N'Wrocław'
WHERE  OrderID = 11000
go
-- 3. That completed fine. But now run this, keeping the transaction open.
UPDATE dbo.Orders
SET    ShipAddress = N'Poznań'
WHERE  OrderID = 10500

-- 4. Since we are updating the same order, this blocks. But this is 
--    not a deadlock, just a plain blocking situation.
-- 5. Move back to the first window.
go
-- 10. In one of the windows, there is an error message. In the other,
-- rollback the transaction.
ROLLBACK TRANSACTION

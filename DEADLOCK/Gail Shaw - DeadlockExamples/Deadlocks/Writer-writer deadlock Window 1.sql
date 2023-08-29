USE AdventureWorks2019
GO

-- basic writer-writer deadlock. Window 1

BEGIN TRANSACTION

SET LOCK_TIMEOUT 300000 -- 5 minutes

UPDATE  Person.Address
SET     ModifiedDate = GETDATE()

-- run to here then switch to Window 2

UPDATE  Person.Person
SET     MiddleName = 'XYZ'
WHERE   FirstName = 'John'

ROLLBACK TRANSACTION

-- once you've run the second half, switch back to window 2 and run the second half of that
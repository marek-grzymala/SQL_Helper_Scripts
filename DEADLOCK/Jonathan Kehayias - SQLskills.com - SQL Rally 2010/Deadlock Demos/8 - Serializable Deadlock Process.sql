/*============================================================================
  File:     8-Serializable Deadlock Process.sql

  Summary:	Executes a process that will trigger a deadlock under
			Serializable Isolation in SQL Server.  This script must be run
			in two windows concurrently for the deadlock to occur.

  Date:     May 2011

  SQL Server Version: 
		2005, 2008, 2008R2
------------------------------------------------------------------------------
  Written by Jonathan M. Kehayias, SQLskills.com
	
  (c) 2011, SQLskills.com. All rights reserved.

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE [AdventureWorks]
GO
DECLARE @NewSales XML
SET @NewSales = (SELECT RevisionNumber, OrderDate, DueDate, ShipDate, Status, 
					OnlineOrderFlag, PurchaseOrderNumber, AccountNumber, 105 AS CustomerID, 
					ContactID, SalesPersonID, TerritoryID, BillToAddressID, ShipToAddressID,
					ShipMethodID, CreditCardID, CreditCardApprovalCode, CurrencyRateID,
					SubTotal, TaxAmt, Freight, Comment
				 FROM Sales.SalesOrderHeader  WITH (NOLOCK)
				 WHERE CustomerID = 106
				 FOR XML PATH('SalesOrderHeader'), ROOT('SalesOrders'), TYPE)

WHILE 1=1
BEGIN
	EXEC dbo.SerializableDeadlock @NewSales
END

--ROLLBACK
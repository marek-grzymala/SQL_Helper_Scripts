/*============================================================================
  File:     10-Serializable Deadlock Fix - UPDLOCK hit.sql

  Summary:	Demonstrates how to resolve a deadlock under Serializable
			isolation by using the UPDLOCK table hint in a IF EXISTS (SELECT
			clause to take a less concurrent lock initially.

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
IF OBJECT_ID('SerializableDeadlock') IS NOT NULL
	DROP PROCEDURE dbo.SerializableDeadlock
GO
CREATE PROCEDURE dbo.SerializableDeadlock @NewSales XML
AS
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

BEGIN TRANSACTION
	IF NOT EXISTS ( SELECT *
				FROM Sales.SalesOrderHeader WITH(UPDLOCK)
				WHERE CustomerID = 105)
	BEGIN

INSERT INTO [AdventureWorks].[Sales].[SalesOrderHeader]
           ([RevisionNumber], [OrderDate], [DueDate], [ShipDate], [Status], 
			[OnlineOrderFlag], [PurchaseOrderNumber], [AccountNumber], [CustomerID], 
			[ContactID], [SalesPersonID], [TerritoryID], [BillToAddressID], [ShipToAddressID],
			[ShipMethodID], [CreditCardID], [CreditCardApprovalCode], [CurrencyRateID],
			[SubTotal], [TaxAmt], [Freight], [Comment])
	SELECT
		n.value('(RevisionNumber)[1]', 'int'),
		n.value('(OrderDate)[1]', 'datetime'),
		n.value('(DueDate)[1]', 'datetime'),
		n.value('(ShipDate)[1]', 'datetime'),
		n.value('(Status)[1]', 'tinyint'),
		n.value('(OnlineOrderFlag)[1]', 'bit'),
		n.value('(PurchaseOrderNumber)[1]', 'nvarchar(25)'),
		n.value('(AccountNumber)[1]', 'nvarchar(15)'),
		n.value('(CustomerID)[1]', 'nvarchar(15)'),
		n.value('(ContactID)[1]', 'int'),
		n.value('(SalesPersonID)[1]', 'int'),
		n.value('(TerritoryID)[1]', 'int'),
		n.value('(BillToAddressID)[1]', 'int'),
		n.value('(ShipToAddressID)[1]', 'int'),
		n.value('(ShipMethodID)[1]', 'int'),
		n.value('(CreditCardID)[1]', 'int'),
		n.value('(CreditCardApprovalCode)[1]', 'varchar(15)'),
		n.value('(CurrencyRateID)[1]', 'int'),
		n.value('(SubTotal)[1]', 'money'),
		n.value('(TaxAmt)[1]', 'money'),
		n.value('(Freight)[1]', 'money'),
		n.value('(Comment)[1]', 'nvarchar(128)')
	FROM @NewSales.nodes('SalesOrders/SalesOrderHeader') q(n)

	END

ROLLBACK
GO
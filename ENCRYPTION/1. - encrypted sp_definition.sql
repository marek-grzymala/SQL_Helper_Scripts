USE [TestDecryption];
GO

CREATE PROCEDURE test_encrp
WITH ENCRYPTION
AS
BEGIN
    PRINT 'testing the encryption';
END;

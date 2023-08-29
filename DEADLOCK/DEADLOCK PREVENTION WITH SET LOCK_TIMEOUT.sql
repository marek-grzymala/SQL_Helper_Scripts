USE [YourDbName]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[sp_YourProcNameHere]
AS

-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		 @counter INT = 1
		,@attempt_threshold INT = 5
		,@is_success BIT = 0
		,@attempt_nr_str VARCHAR(2)
        ,@ErrMsg		VARCHAR(MAX) 
		,@CustomErrorMessage VARCHAR(2048)
		,@@MESSAGE VARCHAR(2048)
        ,@@PROCNAME VARCHAR(255) 
        ,@@USERNAME VARCHAR(32)

		,@ErrorNumber	INT 
		,@ErrorSeverity	INT 
		,@ErrorState	INT 
		,@ErrorLine		INT 
		,@ErrorMessage	VARCHAR(1000) 

		SET @CustomErrorMessage = N'Transaction failed on %s attempt';

-- retry if deadlock occured
WHILE (@counter <= @attempt_threshold AND @is_success = 0)
BEGIN
	BEGIN TRY
----------------------------------------------------------------------------------------------  
		BEGIN TRANSACTION
		SET LOCK_TIMEOUT 900000 -- 15 minutes - set based on max/avg. FROM SSISDB.internal.execution_info for package: PackageName.dtsx

----------------------------------------------------------------------------------------------
--============================================================================================
-- DEADLOCK-PROTECTED CODE HERE:

--============================================================================================
----------------------------------------------------------------------------------------------
 
        COMMIT TRAN;
        SELECT @@PROCNAME = ISNULL(OBJECT_NAME(@@PROCID), 'Unknown Procedure')
		SELECT @@MESSAGE = 'Procedure ' + @@PROCNAME + ' executed successfully! '
		EXEC xp_logevent 60000, @@MESSAGE, informational WITH RESULT SETS NONE; 
		SET @is_success = 1 -- transaction succeeded, so exit the try-block and the while-loop
----------------------------------------------------------------------------------------------  
	END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
			BEGIN
			    ROLLBACK TRANSACTION
			END

				IF (ERROR_NUMBER() IN
					(
					 1204, -- SQLOUTOFLOCKS
					 1205, -- SQLDEADLOCKVICTIM
					 1222  -- SQLREQUESTTIMEOUT
					)
					AND @counter <= @attempt_threshold)
			        BEGIN
			                SET @counter = @counter + 1 -- increment the timeout counter
                            SELECT   
				            		 @ErrorNumber	    = ERROR_NUMBER() 
				            		,@ErrorSeverity     = ERROR_SEVERITY() 
				            	    ,@ErrorState	    = ERROR_STATE() 
				            	    ,@ErrorLine		    = ERROR_LINE() 
				            	    ,@ErrorMessage	    = COALESCE(ERROR_MESSAGE(), 'Unknown') + CHAR(13)

							SELECT @@PROCNAME = ISNULL(OBJECT_NAME(@@PROCID), 'Unknown Procedure')  
							SELECT @@USERNAME = USER_NAME();  
							SELECT @@MESSAGE = 'Procedure ' + @@PROCNAME + ' executed by '  + @@USERNAME + ' is being retried (try nr: '+CONVERT(NVARCHAR(2), @counter)
                                            +') as it failed with error number: ' +CAST(@ErrorNumber AS VARCHAR)
                                            +', severity: '                       +CAST(@ErrorSeverity AS VARCHAR) 
                                            +', state: '                          +CAST(@ErrorState AS VARCHAR)
                                            +', on line: '                        +CAST(@ErrorLine AS VARCHAR)
                                            +', with message: '                   +@ErrorMessage;    

							PRINT(@@MESSAGE)
                            EXEC xp_logevent 60000, @@MESSAGE, informational WITH RESULT SETS NONE; 
			                WAITFOR DELAY '00:01:00'
					END
			ELSE
            /*
                if the error is NOT one of the:
                1204, -- SQLOUTOFLOCKS
                1205, -- SQLDEADLOCKVICTIM
                1222  -- SQLREQUESTTIMEOUT
                then increment the @counter above the @attempt_threshold to fire RAISERROR section at the end 
            */
			  BEGIN
			    SET @counter = @attempt_threshold + 1
			  END

			BEGIN

				SET @ErrMsg = 'Error executing: '   + COALESCE(OBJECT_NAME(@@PROCID), 'Unknown') + CHAR(13) 
					+ 'Error Procedure: '           + COALESCE(ERROR_PROCEDURE(), 'Unknown')
					+ ', Error Number: '            + CAST(ERROR_NUMBER() AS VARCHAR)
					+ ', Error Severity: '          + CAST(ERROR_SEVERITY() AS VARCHAR)
					+ ', Error State: '             + CAST(ERROR_STATE() AS VARCHAR)
					+ ', Error Line: '              + CAST(ERROR_LINE() AS VARCHAR)
					+ ', Error Message: '           + COALESCE(ERROR_MESSAGE(), 'Unknown') + CHAR(13)
					+ ', Server Name: '             + @@SERVERNAME + ' - Database: ' + DB_NAME() + ', User: ' + SUSER_NAME() + ', SPID: ' + CAST(@@SPID AS VARCHAR) + ', Now: ' + CAST(GETDATE() AS VARCHAR(121));
				
				SET @attempt_nr_str = CONVERT(NVARCHAR(2), @counter)
			    SET @ErrMsg = CONCAT(@ErrMsg, ' ', @CustomErrorMessage)
				
                /* RAISERROR only for last attempt of deadlock retry, or for other errors */
					IF @counter > @attempt_threshold
			        RAISERROR (@ErrMsg 
			                  ,@ErrorSeverity 
			        		   -- Optionally override the error to cause a failure 
			        		   --,18 
			                  ,@ErrorState
			                  ,@attempt_nr_str -- first argument to the message text
			                  );
			END
    END CATCH;
END -- end of WHILE loop
END;

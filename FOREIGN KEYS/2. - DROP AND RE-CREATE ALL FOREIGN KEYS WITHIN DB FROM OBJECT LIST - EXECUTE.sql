--USE [YourDbName]
--GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
SET NOCOUNT ON
GO


/* ======================================================================================================================= */
/* !!! ATTENTION - from this line to the end: run this code-section IN A SEPARATE SESSION !!! from first script 
   to avoid accidentally overwriting your [_ForeignKeyConstraintDefinitions] table with empty values 
   after dropping all constraints */
DECLARE
             @Foreign_Key_Id              INT
            ,@Drop_Constraint_Command     NVARCHAR(MAX)
            ,@Recreate_Constraint_Command NVARCHAR(MAX)
            ,@Command                     NVARCHAR(MAX)
            ,@Drop                        BIT
            ,@Recreate                    BIT
            ,@Execute                     BIT
            ,@RowCount                    INT
            ,@LineId                      INT = 1   

SET @Drop = 1
SET @Recreate = 0
/* CAUTION!!!! SETTING @Execute = 1 WILL EXECUTE ALL @Drop OR @Recreate COMMANDS: */
SET @Execute = 0 /* 0 = Print out the @Command only */

SET XACT_ABORT ON
IF (@Execute = 0)
BEGIN
     PRINT('-----------------------------------------------------------------------------------------');
     PRINT('Below is the PRINTOUT ONLY of the commands to be executed once the @Execute is set to = 1');
     PRINT('-----------------------------------------------------------------------------------------');
END

SELECT @RowCount = COUNT(LineId) FROM [dbo].[_ForeignKeyConstraintDefinitions]
WHILE @LineId <= @RowCount
      BEGIN
            SELECT      
                         @Foreign_Key_Id                = [Foreign_Key_Id]              
                        ,@Drop_Constraint_Command       = [Drop_Constraint_Command]     
                        ,@Recreate_Constraint_Command   = [Recreate_Constraint_Command]
            FROM         [dbo].[_ForeignKeyConstraintDefinitions]
            WHERE        LineId = @LineId

                  IF (@Drop = 1 AND @Recreate = 0)
                  BEGIN
                      SET @Command = @Drop_Constraint_Command
                  END
                  ELSE IF (@Drop = 0 AND @Recreate = 1)
                  BEGIN
                      SET @Command = @Recreate_Constraint_Command
                  END
                  ELSE
                  BEGIN
                        RAISERROR('Set one (and only one) of the parameters: @Drop or @Recreate = 1 so that either one of the actions is selected', 16, 1);
                        RETURN;
                  END
                  IF (@Execute = 0)
                  BEGIN                       
                       PRINT(@Command)
                  END
                  IF (@Execute = 1)
                  BEGIN
                      EXECUTE(@Command);
                      PRINT(CONCAT(@Command, ' - Executed Successfully'));
                  END
            SET @LineId = @LineId + 1;
      END

/* ======================================================================================================================= */
/* If you are absolutely sure that you no longer need the [dbo].[_ForeignKeyConstraintDefinitions]  table then drop it: 
DROP TABLE [dbo].[_ForeignKeyConstraintDefinitions] 
*/

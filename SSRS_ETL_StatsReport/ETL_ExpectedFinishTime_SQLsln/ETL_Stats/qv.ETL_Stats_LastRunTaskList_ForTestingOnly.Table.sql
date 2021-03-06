USE [DWHSupport_Audit]
GO
/****** Object:  Table [qv].[ETL_Stats_LastRunTaskList_ForTestingOnly]    Script Date: 12/07/2019 10:34:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qv].[ETL_Stats_LastRunTaskList_ForTestingOnly](
	[SystemKey] [int] NOT NULL,
	[LogID] [bigint] NOT NULL,
	[RunID] [bigint] NOT NULL,
	[TimeRecorded] [datetime] NOT NULL,
	[ChildTaskName] [nvarchar](256) NULL,
	[ProcessName] [nvarchar](256) NULL,
 CONSTRAINT [PK_SysKey_LogID_RunID_2] PRIMARY KEY CLUSTERED 
(
	[SystemKey] ASC,
	[LogID] ASC,
	[RunID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [PRIMARY]
) ON [PRIMARY]
GO

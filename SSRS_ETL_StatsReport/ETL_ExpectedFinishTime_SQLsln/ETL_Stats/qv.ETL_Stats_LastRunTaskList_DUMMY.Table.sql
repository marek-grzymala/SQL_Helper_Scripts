USE [DWHSupport_Audit]
GO
/****** Object:  Table [qv].[ETL_Stats_LastRunTaskList_DUMMY]    Script Date: 12/07/2019 10:34:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qv].[ETL_Stats_LastRunTaskList_DUMMY](
	[SystemKey] [int] NULL,
	[LogID] [bigint] NULL,
	[RunID] [bigint] NULL,
	[TimeRecorded] [datetime] NULL,
	[ChildTaskName] [nvarchar](max) NULL,
	[ProcessName] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

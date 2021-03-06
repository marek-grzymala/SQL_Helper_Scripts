USE [DWHSupport_Audit]
GO
/****** Object:  Table [qv].[ETL_Stats_WinnersAndLosers]    Script Date: 12/07/2019 10:34:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qv].[ETL_Stats_WinnersAndLosers](
	[SystemKey] [int] NOT NULL,
	[RunID] [bigint] NOT NULL,
	[LogID] [bigint] NOT NULL,
	[TimeRecorded] [datetime] NOT NULL,
	[ProcessName] [nvarchar](1024) NOT NULL,
	[NumDaysBack] [int] NOT NULL,
	[TaskDuration] [time](7) NULL,
	[AvgDuration] [time](7) NULL,
	[StDevInMinutes] [int] NULL,
	[DiffFromStdDev] [int] NULL,
	[RecordsPerSecond] [bigint] NULL,
 CONSTRAINT [PK_SysKey_RunID_LogID] PRIMARY KEY CLUSTERED 
(
	[SystemKey] ASC,
	[RunID] ASC,
	[LogID] ASC,
	[TimeRecorded] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [PRIMARY]
) ON [PRIMARY]
GO

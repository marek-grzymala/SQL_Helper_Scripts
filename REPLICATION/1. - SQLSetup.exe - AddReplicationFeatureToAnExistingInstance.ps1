cd "C:\MSSQL\Backup\InstallSrc\"
.\setup.exe /Q /IACCEPTSQLSERVERLICENSETERMS /CONFIGURATIONFILE=C:\MSSQL\Backup\InstallSrc\ConfigurationFile.ini /INSTANCENAME="SQL2019"


ConfigurationFile.ini:
;SQL Server 2019 Configuration File
[OPTIONS]

; By specifying this parameter and accepting Microsoft Python Open and Microsoft Python Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTPYTHONLICENSETERMS="True"

; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 

ACTION="Install"

; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTROPENLICENSETERMS="True"

; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 

SUPPRESSPRIVACYSTATEMENTNOTICE="True"

; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 

ENU="True"

; Setup will not display any user interface. 

; QUIET="False"

; Setup will display progress only, without any user interaction. 

; QUIETSIMPLE="True"

; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 

; UIMODE="AutoAdvance"

; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 

UpdateEnabled="False"

; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 

USEMICROSOFTUPDATE="False"

; Specifies that SQL Server Setup should not display the paid edition notice when ran from the command line. 

SUPPRESSPAIDEDITIONNOTICE="True"

; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 

; UpdateSource="MU"

; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 

FEATURES=REPLICATION

; Displays the command line parameters usage. 

; HELP="False"

; Specifies that the detailed Setup log should be piped to the console. 

; INDICATEPROGRESS="False"

; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 

; X86="False"

; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 

INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"

; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 

INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"

; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 

; INSTANCEID=""

; Specify the installation directory. 

INSTANCEDIR="C:\Program Files\Microsoft SQL Server"

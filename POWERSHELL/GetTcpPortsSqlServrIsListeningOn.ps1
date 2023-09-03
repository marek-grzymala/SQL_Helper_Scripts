﻿Get-NetTcpConnection | select local*, remote*, state, @{Name = "Process"; Expression = {(Get-Process -Id $_.OwningProcess).ProcessName }} | Where {$_.Process -Like "sqlservr"} | Format-Table
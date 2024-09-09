# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
# if Windows-Containers used Docker leaves old container VM Data here:
# Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Hyper-V\Container Utility VM\' | sort LastWriteTime -descending

# remove anything with LastWriteTime older than a day:
Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Hyper-V\Container Utility VM\' -Recurse -File | Where LastWriteTime -lt  (Get-Date).AddDays(-1) | sort LastWriteTime -descending # | Remove-Item -Force

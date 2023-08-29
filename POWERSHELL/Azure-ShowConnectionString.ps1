az storage account show-connection-string --name marekgrzymala2021 --resource-group ResourceGroup

<# 
$Env:AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=marekgrzymala2021;
AccountKey=Pxvu/HK1An2tpi5OZoW5e6xMAzcGd+FnhD8u+KwAGg/Wcl9ubEH3CvRvd8RFez/OGLRchRyPO1xSjEt7aJ75YQ=="

echo $Env:AZURE_STORAGE_CONNECTION_STRING
#>

az storage container create --name container2
az storage container set-permission --name container2 --public-access blob
az storage container delete --name container2

az storage account keys list -n marekgrzymala2021 -g ResourceGroup


https://marekgrzymala2021.blob.core.windows.net/container2/docker_run.txt


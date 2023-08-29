# Define global variables for the script  
$prefixName = '<a prefix name>'  # used as the prefix for the name for various objects  
$subscriptionID = '927d880f-dee8-4260-b53c-f8ea61c15ce8'   # the ID  of subscription name you will use  
$locationName = '<a data center location>'  # the data center region you will use  
$storageAccountName= 'marekgrzymala2021' # the storage account name you will create or use  
$containerName= 'container3'  # the storage container name to which you will attach the SAS policy with its SAS token  
$policyName = $prefixName + 'policy' # the name of the SAS policy 

# Set a variable for the name of the resource group you will create or use  
$resourceGroupName='ResourceGroup'   

# Add an authenticated Azure account for use in the session   
# Connect-AzAccount    

# Set the tenant, subscription and environment for use in the rest of   
Set-AzContext -SubscriptionId $subscriptionID   

# Create a new resource group - comment out this line to use an existing resource group  
# New-AzResourceGroup -Name $resourceGroupName -Location $locationName   

# Create a new Azure Resource Manager storage account - comment out this line to use an existing Azure Resource Manager storage account  
# New-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Type Standard_RAGRS -Location $locationName   

# Get the access keys for the Azure Resource Manager storage account  
$accountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName  

# Create a new storage account context using an Azure Resource Manager storage account  
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $accountKeys[0].Value

# Creates a new container in blob storage  
$container = New-AzStorageContainer -Context $storageContext -Name $containerName  

# Sets up a Stored Access Policy and a Shared Access Signature for the new container  
$policy = New-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $policyName -Context $storageContext -StartTime $(Get-Date).ToUniversalTime().AddMinutes(-5) -ExpiryTime $(Get-Date).ToUniversalTime().AddYears(10) -Permission rwld

# Gets the Shared Access Signature for the policy  
$sas = New-AzStorageContainerSASToken -name $containerName -Policy $policyName -Context $storageContext
Write-Host 'Shared Access Signature= '$($sas.Substring(1))''  

# Sets the variables for the new container you just created
$container = Get-AzStorageContainer -Context $storageContext -Name $containerName
$cbc = $container.CloudBlobContainer 

# Outputs the Transact SQL to the clipboard and to the screen to create the credential using the Shared Access Signature  
Write-Host 'Credential T-SQL'  
$tSql = "CREATE CREDENTIAL [{0}] WITH IDENTITY='Shared Access Signature', SECRET='{1}'" -f $cbc.Uri,$sas.Substring(1)   
$tSql | clip  
Write-Host $tSql 

# Once you're done with the tutorial, remove the resource group to clean up the resources. 
# Remove-AzResourceGroup -Name $resourceGroupName  
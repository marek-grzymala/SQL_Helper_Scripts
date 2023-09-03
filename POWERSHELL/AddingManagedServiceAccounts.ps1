New-ADGroup grGMSA -path 'OU=MSSQL,DC=YourDomain,DC=LOCAL' -GroupScope Global -PassThru -Verbose

Add-AdGroupMember -Identity grGMSA -Members Node1$, Node2$

New-ADServiceAccount -name msaSQL -DNSHostName DC1.YourDomain.LOCAL -PrincipalsAllowedToRetrieveManagedPassword grGMSA -Verbose

Install-ADServiceAccount -Identity msaSQL
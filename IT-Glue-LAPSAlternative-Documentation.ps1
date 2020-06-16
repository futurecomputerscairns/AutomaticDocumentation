param([string]$APIKey = "",
      [string]$ITGOrg = "")




#Importing ITGlue module
If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}

#####################################################################
$APIKEy = $APIKey
$APIEndpoint = "https://api.itglue.com"
$ChangeAdminUsername = $false
$NewAdminUsername = "Unlikelyusername"
#####################################################################

#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKey

function AttemptMatch($attemptedorganisation) {
    $attempted_match = Get-ITGlueOrganizations -filter_name $attemptedorganisation
    if($attempted_match.data[0].attributes.name -eq $attemptedorganisation) {
                    
                $ITGlueOrganisation = $attempted_match.data.id
    }
                else {
                Write-Output "No auto-match was found. Please pass the exact name in ITGlue to -organization <string>" 
                Exit
                }
            return $ITGlueOrganisation
    
               
          }

          Function CreateFailedConfigurationTicket($pubkey, $privkey, $clientid){


            # This is the URL to your manage server.
            $Server = 'api-aus.myconnectwise.net'
    
            # This is the company entered at login
            $Company = 'Future'
    
            # Load the module into memory
            iwr 'https://raw.githubusercontent.com/LabtechConsulting/ConnectWise-Manage-Powershell/master/CWManage.psm1' | iex
    
            # Connect to Manage server
            Connect-CWM -Server $Server -Company $Company -pubkey $pubkey -privatekey $privkey -clientId $clientid
            $SerialNo = (get-ciminstance win32_bios).serialnumber
            $ChildConditions = 'serialNumber like "' + $SerialNo + '"' | Out-String
    
            $Configuration = Get-CWMCompanyConfiguration -Condition $ChildConditions | Select -First 1
    
            $Summary = 'Configuration ' + $Configuration.Name + ' is not syncing with ITGlue'
            $InitialDescription = 'The configuration item for ' + $Configuration.Name + ' does not exist in ITGlue. This issue is preventing the automated local Administrator password management to occur. Please check Connectwise and ITGlue for why the configuration may not be syncing.'
    
            $board = @{
    
            'id' = '6'
            'name' = 'RMM Alerts'
            '_info' = ''
           
            }
    
            $CurrentCompany = @{
                    'id' = $Configuration.company.id 
                    'identifier' = $Configuration.company.identifier
               
            }
            $Type = @{
                    'id' = '207'
                    'name' = 'RMM Automation'
                    '_info' = ''
                    }
    
                    
     
    
            $CWItem = @{
                    'id' = '22'
                    'name' = 'Alert'
                    '_info' = ''
        
            }
    
            $Ticket = @{
                    'Summary' = $Summary
                    'company' = $CurrentCompany
                    'board' = $board
                    'type' = $Type
                    'initialdescription' = $InitialDescription
                    'item' = $CWItem
                }
        
            $Existing = Get-CWMTicket -Condition "summary like '$summary'"
            $Existing = $Existing | Where-Object {$_.closedFlag -ne 'True'}
        
            if ($null -eq $Existing){
           
            New-CWMTicket @Ticket
        
            }
            else{
    
            Write-Host 'Ticket already exists, see ticket' $Existing.id
            }
        
        
    }

$orgID = AttemptMatch $ITGOrg 

#Check for existing config

$ExistingITGlueAsset = (Get-ITGlueConfigurations -filter_serial_number (get-ciminstance win32_bios).serialnumber).data | Select-Object -Last 1

if ($ExistingITGlueAsset){


        add-type -AssemblyName System.Web
        #This is the process we'll be perfoming to set the admin account.
        $LocalAdminPassword = [System.Web.Security.Membership]::GeneratePassword(24,5)
        If($ChangeAdminUsername -eq $false) {
        Set-LocalUser -name "Administrator" -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
        } else {
        $ExistingNewAdmin = get-localuser | Where-Object {$_.Name -eq $NewAdminUsername}
        if(!$ExistingNewAdmin){
        write-host "Creating new user" -ForegroundColor Yellow
        New-LocalUser -Name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
        Add-LocalGroupMember -Group Administrators -Member $NewAdminUsername
        Disable-LocalUser -Name "Administrator"
        }
        else{
            write-host "Updating admin password" -ForegroundColor Yellow
        set-localuser -name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
        }
        }
        if($ChangeAdminUsername -eq $false ) { $username = "Administrator" } else { $Username = $NewAdminUsername }
        #The script uses the following line to find the correct asset by serialnumber, match it, and connect it if found. Don't want it to tag at all? Comment it out by adding #
        #$TaggedResource = (Get-ITGlueConfigurations -organization_id $orgID -filter_serial_number (get-ciminstance win32_bios).serialnumber).data | Select-Object -Last 1
        $PasswordObjectName = "$($Env:COMPUTERNAME) - Local Administrator Account"
        $PasswordObject = @{
            type = 'passwords'
            attributes = @{
                    name = $PasswordObjectName
                    username = $username
                    password = $LocalAdminPassword
                    notes = "Local Admin Password for $($Env:COMPUTERNAME)"
                    resource_id = $ExistingITGlueAsset.Id
            }
        }
        <#
        if($TaggedResource){ 
            $Passwordobject.attributes.Add("resource_id",$TaggedResource.Id)
            $Passwordobject.attributes.Add("resource_type","Configuration")
        }
        #> 
        #Now we'll check if it already exists, if not. We'll create a new one.
        $ExistingPasswordAsset = (Get-ITGluePasswords -filter_organization_id $orgID -filter_name $PasswordObjectName).data
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if(!$ExistingPasswordAsset){
        Write-Host "Creating new Local Administrator Password" -ForegroundColor yellow
        $ITGNewPassword = New-ITGluePasswords -organization_id $orgID -data $PasswordObject
        } else {
        Write-Host "Updating Local Administrator Password" -ForegroundColor Yellow
        $ITGNewPassword = Set-ITGluePasswords -id $ExistingPasswordAsset.id -data $PasswordObject
        }

        else {



        }
}
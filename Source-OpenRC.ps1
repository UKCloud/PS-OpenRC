<#
.Synopsis
   Source an OpenStack OpenRC file in Windows PowerShell.
.DESCRIPTION
   This script allows you to source an OpenRC file that can be downloaded from the 
   OpenStack dashboard for use in Windows. After running the script you'll be able 
   to use the OpenStack command-line tools. These need to be installed separately.
.PARAMETER LiteralPath
   The OpenRC file you downloaded from the OpenStack dashboard.
.EXAMPLE
   Source-OpenRC.ps1 H:\project-openrc.sh
.LINK
   Modified by https://ukcloud.com/ from initial script by http://openstack.naturalis.nl
.Notes
   Last modified by:
   Dudley Andrews
#>

If (!$args) {
    Write-Host "Please provide an OpenRC file as argument."
    Exit
}

ElseIf ($args.count -gt 1) {
    Write-Host "Please provide a single OpenRC file as argument."
    Exit
}

ElseIf (-Not (Test-Path $args[0])) {
    Write-Host "The OpenRC file you specified doesn't exist!"
    Exit
}
Else {
    $openrc = $args[0]
    $error = "The file you specified doesn't seem to be a valid OpenRC file"

    # With the addition of Keystone, to use an openstack cloud you should
    # authenticate against keystone, which returns a **Token** and **Service
    # Catalog**.  The catalog contains the endpoint for all services the
    # user/tenant has access to - including nova, glance, keystone, swift.
    #
    # *NOTE*: Using the 2.0 *auth api* does not mean that compute api is 2.0.  We
    # will use the 1.1 *compute api*

    # Determine OS Identity API Version
    $Content = Get-Content $openrc
    if ($content -match "OS_IDENTITY_API_VERSION=2"){$APIVer = 2}
    elseif ($content -match "OS_IDENTITY_API_VERSION=3"){$APIVer = 3}
    else{
        Write-Error "OS Identity API Version not supported"
        Exit
    }

    # Check if OS_DOMAIN_NAME is set and clear if it is
    if ($env:OS_USER_DOMAIN_NAME){
        Remove-Item env:OS_USER_DOMAIN_NAME
    }

    # Check if OS_REGION_NAME is set and clear if it is
    if ($env:OS_REGION_NAME){
        Remove-Item env:OS_REGION_NAME
    }

    # Check if OS_INTERFACE is set and clear if it is
    if ($env:OS_INTERFACE){
        Remove-Item env:OS_INTERFACE
    }

    # Check if OS_IDENTITY_API_VERSION is set and clear if it is
    if ($env:OS_IDENTITY_API_VERSION){
        Remove-Item env:OS_IDENTITY_API_VERSION
    }

    # Set the tenant/project name & ID depending on which OS Identity API version is in use
    If ($APIVer -eq 2){
        if ($env:OS_PROJECT_NAME){
            Remove-Item env:OS_PROJECT_NAME
        }
        $os_tenant_name = Select-String -Path $openrc -Pattern 'OS_TENANT_NAME='
        $env:OS_TENANT_NAME = [String]$os_tenant_name -split "`"" | Select -Index 1

        if ($env:OS_PROJECT_ID){
            Remove-Item env:OS_PROJECT_ID
        }
        $os_tenant_id = Select-String -Path $openrc -Pattern 'OS_TENANT_ID='
        $env:OS_TENANT_ID = [String]$os_tenant_id -split "=" | Select -Last 1
    }
    ElseIf ($APIVer -eq 3) {
        if ($env:OS_TENANT_NAME){
            Remove-Item env:OS_TENANT_NAME
        }
        $os_project_name = Select-String -Path $openrc -Pattern 'OS_PROJECT_NAME='
        $env:OS_PROJECT_NAME = [String]$os_Project_name -split "`"" | Select -Index 1
        
        if ($env:OS_TENANT_ID){
            Remove-Item env:OS_TENANT_ID
        }
        $os_project_id = Select-String -Path $openrc -Pattern 'OS_Project_ID='
        $env:OS_PROJECT_ID = [String]$os_Project_id -split "=" | Select -Last 1
        
        # Set OS User Domain Name to default
        $env:OS_USER_DOMAIN_NAME = "Default"

        # Set OS Region Name to regionOne
        $env:OS_REGION_NAME = "regionOne"

        # Set OS Interface
        $env:OS_INTERFACE = "public"
        
        # Set OS Itentity API Version
        $env:OS_IDENTITY_API_VERSION = 3
    }
    Else {
        Write-Host $error
        Exit
    }

    $os_auth_url = Select-String -Path $openrc -Pattern 'OS_AUTH_URL='
    If ($os_auth_url) {
        $env:OS_AUTH_URL = [String]$os_auth_url -split "=" | Select -Last 1
    }
    Else {
        Write-Host $error
        Exit
    }

    # In addition to the owning entity (tenant), openstack stores the entity
    # performing the action as the **user**.
    $os_username = Select-String -Path $openrc -Pattern 'OS_USERNAME='
    If ($os_username) {
        $env:OS_USERNAME = [String]$os_username -split "`"" | Select -Index 1
    }
    Else {
        Write-Host $error
        Exit
    }

    # With Keystone you pass the keystone password.
    $password = Read-Host 'Please enter your OpenStack Password' -AsSecureString
    $env:OS_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
}

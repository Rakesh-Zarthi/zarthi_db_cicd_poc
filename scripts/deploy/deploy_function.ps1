###############################################################
#
# Script Name : Deploy-Function.ps1
# Version     : 2.0
# Author      : Kuldeep Singh
# Description : Deploy PostgreSQL Function from Git Repository
#
###############################################################

$ErrorActionPreference = "Stop"

###############################################################
# Banner
###############################################################

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "      PostgreSQL Function Deployment Utility v2.0" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

###############################################################
# Log Folder
###############################################################

$LogFolder = Join-Path $PSScriptRoot "..\..\logs"

if (!(Test-Path $LogFolder))
{
    New-Item `
        -ItemType Directory `
        -Path $LogFolder `
        -Force | Out-Null
}

###############################################################
# Log File
###############################################################

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Script:LogFile = Join-Path `
    $LogFolder `
    "Deploy_$TimeStamp.log"

###############################################################
# Logging Function
###############################################################

function Write-Log
{
    param
    (
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color

    Add-Content `
        -Path $Script:LogFile `
        -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
}

###############################################################
# Read Configuration
###############################################################

$ConfigFile = Join-Path `
    $PSScriptRoot `
    "..\..\config\config.json"

if (!(Test-Path $ConfigFile))
{
    Write-Host ""
    Write-Host "Configuration file not found." -ForegroundColor Red
    Write-Host $ConfigFile
    exit
}

$Config = Get-Content `
    $ConfigFile `
    -Raw |
    ConvertFrom-Json

###############################################################
# PostgreSQL Client
###############################################################

$Psql = $Config.psql.path

if (!(Test-Path $Psql))
{
    Write-Log ""
    Write-Log "psql.exe not found." Red
    Write-Log $Psql Yellow
    exit
}

Write-Log "PostgreSQL Client Found." Green
Write-Log $Psql DarkGray

###############################################################
# Repository
###############################################################

$RepositoryRoot = $Config.repository.root

if (!(Test-Path $RepositoryRoot))
{
    Write-Log ""
    Write-Log "Repository path not found." Red
    Write-Log $RepositoryRoot Yellow
    exit
}

Write-Log ""
Write-Log "Repository Found." Green
Write-Log $RepositoryRoot DarkGray

###############################################################
# Start Time
###############################################################

$StartTime = Get-Date

Write-Log ""
Write-Log "Deployment Started" Cyan
Write-Log "Start Time : $StartTime" DarkGray

###############################################################
# Select Target Environment
###############################################################

Write-Log ""
Write-Log "Available Environments" Yellow

$Config.environments.PSObject.Properties.Name | ForEach-Object {
    Write-Host " - $_"
}

Write-Log ""

$Environment = Read-Host "Target Environment"

if ([string]::IsNullOrWhiteSpace($Environment))
{
    Write-Log "Environment cannot be empty." Red
    exit
}

if (-not ($Config.environments.PSObject.Properties.Name -contains $Environment))
{
    Write-Log "Invalid Environment." Red
    exit
}

$Target = $Config.environments.$Environment

$TargetHost = $Target.host
$TargetPort = $Target.port
$TargetDatabase = $Target.database
$TargetUser = $Target.username

###############################################################
# Password
###############################################################

Write-Log ""
Write-Log "Target Database Authentication" Yellow

$SecurePassword = Read-Host "Password" -AsSecureString

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:PGPASSWORD = $PlainPassword

###############################################################
# Validate Target Database Connection
###############################################################

Write-Log ""
Write-Log "Validating Target Database Connection..." Cyan

$Version = "SELECT version();" | & $Psql `
    -h $TargetHost `
    -p $TargetPort `
    -U $TargetUser `
    -d $TargetDatabase `
    -At

if ($LASTEXITCODE -ne 0)
{
    Write-Log ""
    Write-Log "Unable to connect to Target Database." Red
    exit
}

Write-Log "Connection Successful." Green
Write-Log $Version DarkGray

###############################################################
# Function Information
###############################################################

Write-Log ""
Write-Log "Function Information" Yellow

$Schema = Read-Host "Schema"

if ([string]::IsNullOrWhiteSpace($Schema))
{
    Write-Log "Schema cannot be empty." Red
    exit
}

$FunctionName = Read-Host "Function Name"

if ([string]::IsNullOrWhiteSpace($FunctionName))
{
    Write-Log "Function Name cannot be empty." Red
    exit
}

###############################################################
# Locate SQL File
###############################################################

$SqlFile = Join-Path `
    $RepositoryRoot `
    "schemas\$Schema\functions\$FunctionName.sql"

Write-Log ""
Write-Log "Searching SQL File..." Cyan

if (!(Test-Path $SqlFile))
{
    Write-Log ""
    Write-Log "SQL file not found." Red
    Write-Log $SqlFile Yellow
    exit
}

Write-Log "SQL file located successfully." Green
Write-Log $SqlFile DarkGray

###############################################################
# Deployment Summary
###############################################################

Write-Log ""
Write-Log "============================================================" Cyan
Write-Log "Deployment Summary" Cyan
Write-Log "============================================================" Cyan

Write-Log "Environment      : $Environment"
Write-Log "Target Host      : $TargetHost"
Write-Log "Target Port      : $TargetPort"
Write-Log "Target Database  : $TargetDatabase"
Write-Log "Target User      : $TargetUser"
Write-Log "Schema           : $Schema"
Write-Log "Function         : $FunctionName"
Write-Log "SQL File         : $SqlFile"

Write-Log ""
Write-Log "============================================================" Cyan

###############################################################
# Confirmation
###############################################################

Write-Log ""

$Confirm = Read-Host "Proceed with deployment? (Y/N)"

if ($Confirm.ToUpper() -ne "Y")
{
    Write-Log ""
    Write-Log "Deployment cancelled by user." Yellow

    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

    exit
}

###############################################################
# Deploy Function
###############################################################

Write-Log ""
Write-Log "Deploying Function..." Cyan

& $Psql `
    -h $TargetHost `
    -p $TargetPort `
    -U $TargetUser `
    -d $TargetDatabase `
    -v ON_ERROR_STOP=1 `
    -f $SqlFile

if ($LASTEXITCODE -ne 0)
{
    Write-Log ""
    Write-Log "============================================================" Red
    Write-Log "DEPLOYMENT FAILED" Red
    Write-Log "============================================================" Red

    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

    exit
}

###############################################################
# Deployment Completed
###############################################################

$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

Write-Log ""
Write-Log "============================================================" Green
Write-Log "Deployment Completed Successfully" Green
Write-Log "============================================================" Green

Write-Log "Start Time : $StartTime"
Write-Log "End Time   : $EndTime"
Write-Log ("Duration   : {0:hh\:mm\:ss}" -f $Duration)
###############################################################
#
# Script Name : Export-All-Functions.ps1
# Version     : 1.0
# Author      : Kuldeep Singh
# Description : Export PostgreSQL Functions to Git Repository
#
###############################################################

$ErrorActionPreference = "Stop"

Clear-Host

###############################################################
# Banner
###############################################################

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     PostgreSQL Function Export Utility v1.0" -ForegroundColor Cyan
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
    "Export_Functions_$TimeStamp.log"

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
    Write-Log ""
    Write-Log "Configuration file not found." Red
    Write-Log $ConfigFile Yellow
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
# Repository Path
###############################################################

$RepositoryRoot = $Config.repository.root

if (!(Test-Path $RepositoryRoot))
{
    Write-Log ""
    Write-Log "Repository path not found." Red
    Write-Log $RepositoryRoot Yellow
    exit
}

$SchemasRoot = Join-Path `
    $RepositoryRoot `
    "schemas"

if (!(Test-Path $SchemasRoot))
{
    Write-Log ""
    Write-Log "'schemas' folder not found." Red
    Write-Log $SchemasRoot Yellow
    exit
}

Write-Log ""
Write-Log "Repository Verified." Green
Write-Log $SchemasRoot DarkGray

###############################################################
# Source Database
###############################################################

Write-Log ""
Write-Log "Source Database Information" Yellow

$SourceHost = Read-Host "Source Host"

$SourcePort = Read-Host "Port"

if([string]::IsNullOrWhiteSpace($SourcePort))
{
    $SourcePort = 5432
}

$SourceDatabase = Read-Host "Database"

$SourceUser = Read-Host "Username"

$SecurePassword = Read-Host "Password" -AsSecureString

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:PGPASSWORD = $PlainPassword

###############################################################
# Validate Source Database Connection
###############################################################

Write-Log ""
Write-Log "Validating Source Database Connection..." Cyan

$Version = "SELECT version();" | & $Psql `
    -h $SourceHost `
    -p $SourcePort `
    -U $SourceUser `
    -d $SourceDatabase `
    -At

if($LASTEXITCODE -ne 0)
{
    Write-Log ""
    Write-Log "Unable to connect to Source Database." Red
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    exit
}

Write-Log "Connection Successful." Green
Write-Log $Version DarkGray

###############################################################
# Initialize Counters
###############################################################

$Script:TotalSchemas   = 0
$Script:TotalFunctions = 0
$Script:Exported       = 0
$Script:Skipped        = 0
$Script:Failed         = 0

###############################################################
# Start Time
###############################################################

$StartTime = Get-Date

Write-Log ""
Write-Log "Export Started" Cyan
Write-Log "Start Time : $StartTime" DarkGray

##### Part 1 end####

###############################################################
# Read Schema Directories
###############################################################

Write-Log ""
Write-Log "Scanning Repository Schemas..." Cyan

$SchemaFolders = Get-ChildItem `
    -Path $SchemasRoot `
    -Directory |
    Sort-Object Name

if($SchemaFolders.Count -eq 0)
{
    Write-Log "No schema folders found." Red

    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

    exit
}

###############################################################
# Export Collection
###############################################################

$Script:ExportList = @()

###############################################################
# Process Each Schema
###############################################################

foreach($SchemaFolder in $SchemaFolders)
{
    $Schema = $SchemaFolder.Name

    $Script:TotalSchemas++

    Write-Log ""
    Write-Log "------------------------------------------------------------" DarkGray
    Write-Log "Schema : $Schema" Yellow

    ###########################################################
    # Ensure Functions Folder
    ###########################################################

    $FunctionsFolder = Join-Path `
        $SchemaFolder.FullName `
        "functions"

    if(!(Test-Path $FunctionsFolder))
    {
        New-Item `
            -ItemType Directory `
            -Path $FunctionsFolder `
            -Force | Out-Null

        Write-Log "Created folder : functions" DarkGray
    }

    ###########################################################
    # Read Functions
    ###########################################################

    $Query = @"
SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE
n.nspname='$Schema'
ORDER BY
p.proname;
"@

    $Result = $Query | & $Psql `
        -h $SourceHost `
        -p $SourcePort `
        -U $SourceUser `
        -d $SourceDatabase `
        -At `
        -F "|"

    if($LASTEXITCODE -ne 0)
    {
        Write-Log "Unable to read functions." Red
        continue
    }

    if([string]::IsNullOrWhiteSpace($Result))
    {
        Write-Log "No functions found." DarkGray
        continue
    }

    ###########################################################
    # Build Export List
    ###########################################################

    foreach($Row in $Result)
    {
        $Columns = $Row.Split("|")

        $Script:ExportList += [PSCustomObject]@{

            Schema = $Schema

            OID = $Columns[0]

            Name = $Columns[1]

            Arguments = $Columns[2]

            Folder = $FunctionsFolder
        }

        $Script:TotalFunctions++
    }

    Write-Log "Functions Found : $($Result.Count)" Green
}

###############################################################
# Summary
###############################################################

Write-Log ""
Write-Log "============================================================" Cyan
Write-Log "Discovery Completed" Cyan
Write-Log "============================================================" Cyan

Write-Log "Schemas Scanned  : $Script:TotalSchemas"
Write-Log "Functions Found  : $Script:TotalFunctions"

### Part 2 end ###

###############################################################
# Export Functions
###############################################################

Write-Log ""
Write-Log "Starting Function Export..." Cyan

###############################################################
# PostgreSQL Client Encoding
###############################################################

$env:PGCLIENTENCODING = "UTF8"

foreach($Function in $Script:ExportList)
{
    Write-Log ""
    Write-Log "------------------------------------------------------------" DarkGray
    Write-Log "Schema   : $($Function.Schema)"
    Write-Log "Function : $($Function.Name)"

    ###########################################################
    # Safe File Name
    ###########################################################

    $SafeArguments = $Function.Arguments

    $SafeArguments = $SafeArguments -replace '\s+', ''
    $SafeArguments = $SafeArguments -replace ',', '_'
    $SafeArguments = $SafeArguments -replace '\(', ''
    $SafeArguments = $SafeArguments -replace '\)', ''
    $SafeArguments = $SafeArguments -replace '\[\]', '_array'
    $SafeArguments = $SafeArguments -replace '"',''
    $SafeArguments = $SafeArguments -replace '[^a-zA-Z0-9_]', '_'

    if([string]::IsNullOrWhiteSpace($SafeArguments))
    {
        $FileName = "$($Function.Name).sql"
    }
    else
    {
        $FileName = "$($Function.Name)__$SafeArguments.sql"
    }

    $OutputFile = Join-Path `
        $Function.Folder `
        $FileName

    ###########################################################
    # Export Function Definition
    ###########################################################

    try
    {
        $Definition = & $Psql `
            -h $SourceHost `
            -p $SourcePort `
            -U $SourceUser `
            -d $SourceDatabase `
            -X `
            -A `
            -t `
            -c "SELECT pg_get_functiondef($($Function.OID));"

        if($LASTEXITCODE -ne 0)
        {
            throw "pg_get_functiondef failed."
        }

        #######################################################
        # Preserve Multiline Output
        #######################################################

        if($Definition -is [array])
        {
            $Definition = ($Definition | Out-String).TrimEnd()
        }

        #######################################################
        # Remove Leading/Trailing Blank Lines Only
        #######################################################

        $Definition = $Definition.Trim()

        #######################################################
        # Debug Information
        #######################################################

        Write-Log "Export Size : $($Definition.Length) characters" DarkGray

        if($Definition.Length -gt 20)
        {
            Write-Log "Last 20 Characters :" DarkGray
            Write-Log $Definition.Substring($Definition.Length - 20) DarkGray
        }

        #######################################################
        # Save SQL File (UTF8 without BOM)
        #######################################################

        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        [System.IO.File]::WriteAllText(
            $OutputFile,
            $Definition,
            $Utf8NoBom
        )

        Write-Log "Exported : $FileName" Green

        $Script:Exported++
    }
    catch
    {
        Write-Log "FAILED : $FileName" Red
        Write-Log $_.Exception.Message Red

        $Script:Failed++
    }
}

###############################################################
# End of Part 3
###############################################################

###############################################################
# Remove Orphan SQL Files
###############################################################

Write-Log ""
Write-Log "Checking for orphan SQL files..." Cyan

foreach($SchemaFolder in $SchemaFolders)
{
    $FunctionsFolder = Join-Path $SchemaFolder.FullName "functions"

    if(!(Test-Path $FunctionsFolder))
    {
        continue
    }

    $ExportedFiles = $Script:ExportList |
        Where-Object {$_.Schema -eq $SchemaFolder.Name} |
        ForEach-Object {

            $Args = $_.Arguments

            $Args = $Args -replace '\s+', ''
            $Args = $Args -replace ',', '_'
            $Args = $Args -replace '\(', ''
            $Args = $Args -replace '\)', ''
            $Args = $Args -replace '\[\]', '_array'
            $Args = $Args -replace '"',''
            $Args = $Args -replace '[^a-zA-Z0-9_]', '_'

            if([string]::IsNullOrWhiteSpace($Args))
            {
                "$($_.Name).sql"
            }
            else
            {
                "$($_.Name)__$Args.sql"
            }
        }

    Get-ChildItem $FunctionsFolder -Filter *.sql | ForEach-Object {

        if($_.Name -notin $ExportedFiles)
        {
            Remove-Item $_.FullName -Force

            Write-Log "Removed orphan file : $($_.Name)" Yellow
        }
    }
}

###############################################################
# Export Report
###############################################################

$ReportFile = Join-Path `
    $LogFolder `
    "Export_Report_$TimeStamp.csv"

$Script:ExportList |
Select-Object `
Schema,
Name,
Arguments,
Folder |
Export-Csv `
-NoTypeInformation `
-Path $ReportFile

###############################################################
# Summary
###############################################################

$EndTime = Get-Date

$Duration = New-TimeSpan `
-Start $StartTime `
-End $EndTime

Write-Log ""
Write-Log "============================================================" Green
Write-Log "Export Completed Successfully" Green
Write-Log "============================================================" Green

Write-Log ""
Write-Log "Schemas Processed : $Script:TotalSchemas"
Write-Log "Functions Found   : $Script:TotalFunctions"
Write-Log "Functions Exported: $Script:Exported"
Write-Log "Failed            : $Script:Failed"

Write-Log ""
Write-Log "Repository"

Write-Log $SchemasRoot DarkGray

Write-Log ""
Write-Log "Report"

Write-Log $ReportFile DarkGray

Write-Log ""
Write-Log "Start Time : $StartTime"
Write-Log "End Time   : $EndTime"
Write-Log ("Duration   : {0:hh\:mm\:ss}" -f $Duration)

###############################################################
# Cleanup
###############################################################

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

Write-Log ""
Write-Log "Cleanup completed." DarkGray

exit 0

## part 4 end ##


###############################################################
# Export-Functions.ps1
#
# Purpose:
# Export all PostgreSQL functions from Production RDS
# into Git repository (one SQL file per function)
###############################################################

Clear-Host

Write-Host ""
Write-Host "==============================================="
Write-Host " PostgreSQL Function Export Utility"
Write-Host "==============================================="
Write-Host ""

#-------------------------------------------------------------
# Repository Root
#-------------------------------------------------------------

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."

#-------------------------------------------------------------
# Read Configuration
#-------------------------------------------------------------

$configFile = Join-Path $RepoRoot "config\settings.json"

if (!(Test-Path $configFile))
{
    Write-Host "Configuration file not found." -ForegroundColor Red
    exit
}

$config = Get-Content $configFile -Raw | ConvertFrom-Json

$psql = $config.postgres.psqlPath

$db = $config.production

$env:PGPASSWORD = $db.password

#-------------------------------------------------------------
# Validate psql
#-------------------------------------------------------------

if (!(Test-Path $psql))
{
    Write-Host "psql.exe not found." -ForegroundColor Red
    exit
}

#-------------------------------------------------------------
# Get User Schemas
#-------------------------------------------------------------

$tempSchemaFile = Join-Path $env:TEMP "schemas.txt"

$schemaQuery = @"
SELECT nspname
FROM pg_namespace
WHERE nspname NOT IN
(
'pg_catalog',
'information_schema'
)
AND nspname NOT LIKE 'pg_toast%'
ORDER BY nspname;
"@

$schemaQuery |
& $psql `
-h $db.host `
-p $db.port `
-U $db.username `
-d $db.database `
-At `
-o $tempSchemaFile

if (!(Test-Path $tempSchemaFile))
{
    Write-Host "Unable to retrieve schemas." -ForegroundColor Red
    exit
}

$schemas = Get-Content $tempSchemaFile

#-------------------------------------------------------------
# Export Each Schema
#-------------------------------------------------------------

foreach($schema in $schemas)
{

    Write-Host ""
    Write-Host "Processing Schema : $schema" -ForegroundColor Cyan

    $schemaFolder = Join-Path $RepoRoot "schemas\$schema\functions"

    if (!(Test-Path $schemaFolder))
    {
        New-Item `
        -ItemType Directory `
        -Path $schemaFolder `
        -Force | Out-Null
    }

    $query = @"
SELECT
proname,
pg_get_function_identity_arguments(p.oid),
pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE n.nspname='$schema'
AND p.prokind='f'
ORDER BY proname;
"@

    $tempCsv = Join-Path $env:TEMP "$schema-functions.csv"

    $query |
    & $psql `
    -h $db.host `
    -p $db.port `
    -U $db.username `
    -d $db.database `
    --csv `
    -o $tempCsv

    if (!(Test-Path $tempCsv))
    {
        continue
    }

    $functions = Import-Csv $tempCsv

    foreach($fn in $functions)
    {

        $functionName = $fn.proname

        $args = $fn.pg_get_function_identity_arguments

        $definition = $fn.pg_get_functiondef

        if([string]::IsNullOrWhiteSpace($args))
        {
            $safeArgs = ""
        }
        else
        {
            $safeArgs = $args `
                -replace '[<>:"/\\|?*]', '_' `
                -replace ',', '_' `
                -replace '\s+', '_'
        }

        if($safeArgs -eq "")
        {
            $fileName = "$functionName.sql"
        }
        else
        {
            $fileName = "$functionName($safeArgs).sql"
        }

        $filePath = Join-Path $schemaFolder $fileName

        $definition |
        Out-File `
        -FilePath $filePath `
        -Encoding utf8

        Write-Host "  Exported : $fileName"

    }

}

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==============================================="
Write-Host " Export Completed Successfully"
Write-Host "==============================================="
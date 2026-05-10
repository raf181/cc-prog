param(
    [string]$File = "setup.lua",
    [string]$Name = "quarry setup",
    [ValidateSet("0", "1", "2")]
    [string]$Private = "1",
    [string]$Expire = "N",
    [string]$Manifest = "pastebin-pastes.json",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $env:PASTEBIN_DEV_KEY) {
    throw "Set PASTEBIN_DEV_KEY before publishing."
}

function Get-PasteKeyFromUrl {
    param([string]$Url)
    return ($Url -split "/")[-1]
}

function Read-Manifest {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{}
    }

    $json = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($json)) {
        return [ordered]@{}
    }

    $parsed = $json | ConvertFrom-Json -AsHashtable
    if ($parsed) {
        $ordered = [ordered]@{}
        foreach ($key in $parsed.Keys) {
            $ordered[$key] = $parsed[$key]
        }
        return $ordered
    }

    return [ordered]@{}
}

function Write-Manifest {
    param(
        [string]$Path,
        [hashtable]$Data
    )

    $Data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path
}

$localContent = Get-Content -LiteralPath $File -Raw
$manifestData = Read-Manifest -Path $Manifest
$manifestKey = $File -replace '\\', '/'
$existingPaste = $manifestData[$manifestKey]

if ($existingPaste -and -not $Force) {
    $rawUrl = "https://pastebin.com/raw/$existingPaste"
    try {
        $remoteContent = Invoke-RestMethod -Uri $rawUrl -Method Get
        if ($remoteContent -eq $localContent) {
            Write-Host "No changes for $File; existing paste is https://pastebin.com/$existingPaste"
            Write-Host "Install command: pastebin get $existingPaste setup"
            return
        }
    }
    catch {
        Write-Warning "Could not read existing paste $existingPaste. A new paste will be created."
    }

    Write-Warning "Pastebin's API cannot edit paste $existingPaste in place. A changed file requires a new paste key."
}

$body = @{
    api_dev_key = $env:PASTEBIN_DEV_KEY
    api_option = "paste"
    api_paste_code = $localContent
    api_paste_name = $Name
    api_paste_format = "lua"
    api_paste_private = $Private
    api_paste_expire_date = $Expire
}

if ($env:PASTEBIN_USER_KEY) {
    $body.api_user_key = $env:PASTEBIN_USER_KEY
}

$response = Invoke-RestMethod -Uri "https://pastebin.com/api/api_post.php" -Method Post -Body $body
if ($response -like "Bad API request,*") {
    throw $response
}

$key = ($response -split "/")[-1]
$manifestData[$manifestKey] = $key
Write-Manifest -Path $Manifest -Data $manifestData

Write-Host "Published $File to $response"
Write-Host "Install command: pastebin get $key setup"
Write-Host "Recorded paste key in $Manifest"

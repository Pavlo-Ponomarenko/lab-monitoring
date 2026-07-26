<#
.SYNOPSIS
    Builds Docker images from local folders and pushes them to their matching
    AWS ECR repositories in eu-central-1.

.DESCRIPTION
    For each folder/repo pair, this script:
      1. Looks up the ECR repository URI via `aws ecr describe-repositories`
         (this URI includes the registry's DNS name, e.g.
         123456789012.dkr.ecr.eu-central-1.amazonaws.com/lab-monitoring-web)
      2. Logs Docker in to the ECR registry (done once)
      3. Builds the Dockerfile in each folder
      4. Tags the image with the repo URI
      5. Pushes it to ECR

.PARAMETER Tag
    Image tag to use for all images. Defaults to "latest".

.PARAMETER Region
    AWS region. Defaults to "eu-central-1".

.EXAMPLE
    .\build-and-push.ps1
    .\build-and-push.ps1 -Tag v1.2.3
#>

[CmdletBinding()]
param(
    [string]$Region = "eu-central-1",
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"

# Map local folder -> ECR repository name
$Repos = [ordered]@{
    "web"          = "lab-monitoring-web"
    "prometheus"   = "lab-monitoring-prometheus"
    "grafana"      = "lab-monitoring-grafana"
    "alertmanager" = "lab-monitoring-alertmanager"
}

# Root folder containing the four subfolders (defaults to script's own folder)
$RootPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($RootPath)) {
    $RootPath = (Get-Location).Path
}

function Assert-CommandExists {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH. Please install it first."
    }
}

Assert-CommandExists -Name "aws"
Assert-CommandExists -Name "docker"

Write-Host "== Resolving ECR repository URIs in region $Region ==" -ForegroundColor Cyan

# repoUri -> "registry.dkr.ecr.region.amazonaws.com/repo-name"
$RepoUris = [ordered]@{}

foreach ($folder in $Repos.Keys) {
    $repoName = $Repos[$folder]

    $uri = aws ecr describe-repositories `
        --repository-names $repoName `
        --region $Region `
        --query "repositories[0].repositoryUri" `
        --output text

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uri) -or $uri -eq "None") {
        throw "Could not resolve ECR repository URI for '$repoName'. Does it exist in $Region?"
    }

    $RepoUris[$folder] = $uri.Trim()
    Write-Host ("  {0,-15} -> {1}" -f $folder, $uri.Trim())
}

# Derive the registry DNS name (same for all repos, e.g. 123456789012.dkr.ecr.eu-central-1.amazonaws.com)
$RegistryDns = ($RepoUris.Values | Select-Object -First 1).Split('/')[0]

Write-Host "`n== Logging in to ECR registry $RegistryDns ==" -ForegroundColor Cyan
$loginPassword = aws ecr get-login-password --region $Region
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($loginPassword)) {
    throw "Failed to get ECR login password."
}
$loginPassword | docker login --username AWS --password-stdin $RegistryDns
if ($LASTEXITCODE -ne 0) {
    throw "docker login to $RegistryDns failed."
}

Write-Host "`n== Building and pushing images ==" -ForegroundColor Cyan

foreach ($folder in $Repos.Keys) {
    $folderPath = Join-Path $RootPath $folder
    $dockerfilePath = Join-Path $folderPath "Dockerfile"
    $repoUri = $RepoUris[$folder]
    $imageTag = "${repoUri}:${Tag}"

    if (-not (Test-Path $dockerfilePath)) {
        throw "Dockerfile not found at $dockerfilePath"
    }

    Write-Host "`n--- $folder ---" -ForegroundColor Yellow
    Write-Host "Building $imageTag from $folderPath"
    docker build -t $imageTag $folderPath
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed for $folder"
    }

    Write-Host "Pushing $imageTag"
    docker push $imageTag
    if ($LASTEXITCODE -ne 0) {
        throw "docker push failed for $folder"
    }
}

Write-Host "`nAll images built and pushed successfully." -ForegroundColor Green
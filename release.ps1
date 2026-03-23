param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$Tag = "v$Version"

git add -A
git commit -m "$Tag"
git tag $Tag
git push origin main --tags

Write-Host "Released $Tag"

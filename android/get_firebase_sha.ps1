# Run signing report and print SHA-1/SHA-256 for adding to Firebase Console.
# Fixes: Firebase Auth 17028 "Invalid app info in play_integrity_token"
# Usage: From repo root: .\android\get_firebase_sha.ps1
#        Or from android/: .\get_firebase_sha.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host ""
Write-Host "Running Gradle signing report..." -ForegroundColor Cyan
$out = & .\gradlew.bat signingReport 2>&1 | Out-String

$sha1 = $out | Select-String -Pattern "SHA1:\s+([A-F0-9:]+)" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1
$sha256 = $out | Select-String -Pattern "SHA256:\s+([A-F0-9:]+)" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1

Write-Host ""
if ($sha1 -or $sha256) {
    Write-Host "Add these to Firebase Console:" -ForegroundColor Green
    Write-Host "  Project Settings -> Your apps -> Android (com.linemeup.parent) -> Add fingerprint" -ForegroundColor Gray
    Write-Host ""
    if ($sha1) { Write-Host "  SHA-1:   $sha1" -ForegroundColor Yellow }
    if ($sha256) { Write-Host "  SHA-256: $sha256" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Then re-download google-services.json if prompted." -ForegroundColor Gray
} else {
    Write-Host "Could not parse SHA from output. Run manually: .\gradlew signingReport" -ForegroundColor Red
    Write-Host $out
}
Write-Host ""
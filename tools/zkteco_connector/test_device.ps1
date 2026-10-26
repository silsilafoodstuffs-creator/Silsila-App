$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$tokenPath = Join-Path $PSScriptRoot ".local-token"
if (-not (Test-Path $tokenPath)) {
  Write-Host "Local token file not found. Start run_local_windows.ps1 first." -ForegroundColor Red
  exit 1
}
$token = (Get-Content -Raw $tokenPath).Trim()
if ($token.Length -lt 24) { throw "Local token file is invalid." }

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$body = @{ ip = "192.168.2.200"; port = 4370; comm_key = 0; timeout = 8 } | ConvertTo-Json
try {
  $result = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/device/test" -Headers $headers -Body $body -TimeoutSec 20
  $result | ConvertTo-Json -Depth 5
  if (-not $result.ok) { throw "Device protocol test did not return ok=true." }
  if ($result.serial_number -and $result.serial_number -ne "BRC7221760604") {
    Write-Host "WARNING: The returned serial differs from the expected device serial." -ForegroundColor Yellow
    exit 2
  }
  Write-Host "Connector returned a protocol-level response. Confirm serial number before production use." -ForegroundColor Green
} catch {
  Write-Host "Device protocol test failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

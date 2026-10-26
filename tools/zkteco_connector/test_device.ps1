$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $env:SILSILA_ZK_TOKEN -or $env:SILSILA_ZK_TOKEN.Length -lt 24) {
  Write-Host "SILSILA_ZK_TOKEN is not set in this PowerShell session." -ForegroundColor Red
  Write-Host "Use the same PowerShell session as the connector, or copy the token privately into this session." -ForegroundColor Yellow
  exit 1
}

$headers = @{ Authorization = "Bearer $env:SILSILA_ZK_TOKEN"; "Content-Type" = "application/json" }
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

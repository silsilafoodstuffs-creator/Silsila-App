$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Host "Python launcher (py) not found. Install Python 3.11+ from python.org and enable Add Python to PATH." -ForegroundColor Red
  Read-Host "Press Enter to exit"
  exit 1
}

if (-not (Test-Path ".venv\Scripts\python.exe")) {
  py -3 -m venv .venv
}
& ".\.venv\Scripts\python.exe" -m pip install --upgrade pip
& ".\.venv\Scripts\python.exe" -m pip install -r requirements.txt

if (-not $env:SILSILA_ZK_TOKEN -or $env:SILSILA_ZK_TOKEN.Length -lt 24) {
  $bytes = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $env:SILSILA_ZK_TOKEN = [Convert]::ToBase64String($bytes)
}
if (-not $env:SILSILA_ALLOWED_ORIGINS) {
  $env:SILSILA_ALLOWED_ORIGINS = "https://silsilafoodstuffs-creator.github.io"
}

Write-Host ""
Write-Host "موصل سلسلة سيعمل محليًا فقط على 127.0.0.1:8765." -ForegroundColor Green
Write-Host "رمز الجلسة تم توليده محليًا ولا تشاركه." -ForegroundColor Yellow
Write-Host "بعد التشغيل، افتح نافذة PowerShell أخرى داخل هذا المجلد وشغّل test_device.ps1." -ForegroundColor Cyan
& ".\.venv\Scripts\python.exe" -m uvicorn app:app --host 127.0.0.1 --port 8765

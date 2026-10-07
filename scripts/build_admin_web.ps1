param(
  [string]$ProjectRoot = "C:\Users\FURKAN\Desktop\dorduncu"
)

$ErrorActionPreference = "Stop"

$siteKey = $env:ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY

if ([string]::IsNullOrWhiteSpace($siteKey)) {
  throw "ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY ortam değişkeni tanımlı değil."
}

$webDir = Join-Path $ProjectRoot "web"
$indexPath = Join-Path $webDir "index.html"
$adminIndexPath = Join-Path $webDir "admin_index.html"
$indexBackupPath = Join-Path $webDir "index.html.admin-build-backup"

$buildDir = Join-Path $ProjectRoot "build"
$defaultWebBuild = Join-Path $buildDir "web"
$adminWebBuild = Join-Path $buildDir "web_admin"
$userWebBuildBackup = Join-Path $buildDir "web.user-build-backup"

if (-not (Test-Path $indexPath)) {
  throw "Dosya bulunamadı: $indexPath"
}

if (-not (Test-Path $adminIndexPath)) {
  throw "Dosya bulunamadı: $adminIndexPath"
}

if (Test-Path $indexBackupPath) {
  Remove-Item $indexBackupPath -Force
}

if (Test-Path $userWebBuildBackup) {
  Remove-Item $userWebBuildBackup -Recurse -Force
}

Copy-Item $indexPath $indexBackupPath -Force

try {
  Copy-Item $adminIndexPath $indexPath -Force

  if (Test-Path $defaultWebBuild) {
    Move-Item $defaultWebBuild $userWebBuildBackup -Force
  }

  Push-Location $ProjectRoot
  try {
    flutter build web `
      --target=lib/admin_web/main_admin.dart `
      --release `
      --dart-define="ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY=$siteKey"

    if ($LASTEXITCODE -ne 0) {
      throw "Admin Web release build başarısız."
    }
  }
  finally {
    Pop-Location
  }

  if (Test-Path $adminWebBuild) {
    Remove-Item $adminWebBuild -Recurse -Force
  }

  if (-not (Test-Path $defaultWebBuild)) {
    throw "Beklenen admin build klasörü oluşmadı: $defaultWebBuild"
  }

  Move-Item $defaultWebBuild $adminWebBuild -Force

  Write-Host ""
  Write-Host "Admin Web build hazır:" -ForegroundColor Green
  Write-Host $adminWebBuild -ForegroundColor Green
}
finally {
  if (Test-Path $indexBackupPath) {
    Move-Item $indexBackupPath $indexPath -Force
  }

  if (Test-Path $userWebBuildBackup) {
    if (Test-Path $defaultWebBuild) {
      Remove-Item $defaultWebBuild -Recurse -Force
    }

    Move-Item $userWebBuildBackup $defaultWebBuild -Force
  }
}

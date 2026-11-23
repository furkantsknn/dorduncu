param(
  [string]$PlistPath = "ios/Runner/GoogleService-Info.plist",
  [string]$InfoPlistPath = "ios/Runner/Info.plist"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PlistPath)) {
  throw "Missing $PlistPath. Download GoogleService-Info.plist for com.dortapp.dort from Firebase project dorduncu-8e599."
}

$raw = Get-Content -Path $PlistPath -Raw -Encoding UTF8
if ($raw -match "REPLACE_FROM_FIREBASE_CONSOLE") {
  throw "$PlistPath still contains placeholder values."
}

[xml]$plistXml = $raw
$dict = $plistXml.plist.dict
$map = @{}
$children = @($dict.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
for ($i = 0; $i -lt $children.Count - 1; $i += 2) {
  if ($children[$i].Name -eq 'key') {
    $map[$children[$i].InnerText] = $children[$i + 1].InnerText
  }
}

if ($map['BUNDLE_ID'] -ne 'com.dortapp.dort') {
  throw "GoogleService-Info.plist BUNDLE_ID is '$($map['BUNDLE_ID'])', expected 'com.dortapp.dort'."
}
if ($map['PROJECT_ID'] -ne 'dorduncu-8e599') {
  throw "GoogleService-Info.plist PROJECT_ID is '$($map['PROJECT_ID'])', expected 'dorduncu-8e599'."
}
$googleAppId = $map['GOOGLE_APP_ID']
if (-not $googleAppId) {
  throw "GoogleService-Info.plist is missing GOOGLE_APP_ID."
}

$encodedAppId = "app-" + ($googleAppId -replace ":", "-")
$schemes = @($encodedAppId)
if ($map['REVERSED_CLIENT_ID']) {
  $schemes += $map['REVERSED_CLIENT_ID']
}

$infoRaw = Get-Content -Path $InfoPlistPath -Raw -Encoding UTF8
$missing = @($schemes | Where-Object { $infoRaw -notmatch [regex]::Escape($_) })

if ($missing.Count -gt 0) {
  $urlTypeEntries = ($missing | ForEach-Object {
@"
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>$_</string>
			</array>
		</dict>
"@
  }) -join "`n"

  if ($infoRaw -match '<key>CFBundleURLTypes</key>\s*<array>') {
    $infoRaw = $infoRaw -replace '(<key>CFBundleURLTypes</key>\s*<array>)', "`$1`n$urlTypeEntries"
  } else {
    $block = "`t<key>CFBundleURLTypes</key>`n`t<array>`n$urlTypeEntries`n`t</array>`n</dict>"
    $infoRaw = $infoRaw -replace '</dict>\s*</plist>', "$block`n</plist>"
  }

  $resolvedInfoPath = (Resolve-Path $InfoPlistPath).Path
  [System.IO.File]::WriteAllText($resolvedInfoPath, $infoRaw, (New-Object System.Text.UTF8Encoding($false)))
  [void][xml](Get-Content -Path $resolvedInfoPath -Raw -Encoding UTF8)
  Write-Output "Injected Firebase Phone Auth URL schemes into $InfoPlistPath`: $($missing -join ', ')"
} else {
  Write-Output "Firebase Phone Auth URL schemes already present in $InfoPlistPath."
}

Write-Output "Validated Firebase iOS configuration for com.dortapp.dort ($googleAppId)."

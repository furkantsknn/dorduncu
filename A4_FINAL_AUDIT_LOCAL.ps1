$ErrorActionPreference = "Continue"
$root = "C:\Users\FURKAN\Desktop\dorduncu"
$report = "$env:USERPROFILE\Desktop\A4_FINAL_REPORT.txt"
$out = @()

function Add($x="") {
    $script:out += $x
    Write-Host $x
}

cd $root

Add "===== FLUTTER ANALYZE ====="
$fa = flutter analyze 2>&1 | Out-String
Add $fa

cd "$root\functions"
Add "===== FUNCTIONS LINT ====="
$lint = npm run lint 2>&1 | Out-String
Add $lint

Add "===== FUNCTIONS BUILD ====="
$build = npm run build 2>&1 | Out-String
Add $build

cd $root

Add "===== CLIENT FINANCE / SESSION / EVENT WRITES ====="
$danger = Get-ChildItem .\lib -Recurse -Filter *.dart |
Select-String -Pattern `
"collection\('payments'\)|collection\('payment_logs'\)|FieldValue\.increment|runTransaction\(|activeSessionId.*=|collection\('sessions'\).*set|collection\('sessions'\).*update|availableBalanceKurus.*[+\-]|pendingBalanceKurus.*[+\-]" |
Select-Object Path,LineNumber,Line

if ($danger) {
    Add ($danger | Format-Table -AutoSize | Out-String)
} else {
    Add "SONUC_YOK"
}

Add "===== CALLABLE APP CHECK / AUTH ====="

Get-ChildItem .\functions\src -Recurse -Filter *.ts | ForEach-Object {
    $t = Get-Content $_.FullName -Raw

    if ($t -match "onCall\(") {
        $app = $t -match "enforceAppCheck\s*:\s*true"
        $auth = $t -match "request\.auth|assertAdmin|assertAuthenticated"

        Add "$($_.FullName.Replace($root+'\','')) | AppCheck=$app | Auth=$auth"
    }
}

Add "===== FIRESTORE RULES ====="

$fr = Get-Content .\firestore.rules -Raw

Add ("sessions client write blocked = " +
    [bool]($fr -match "match /sessions/\{uid\}[\s\S]{0,400}allow create, update, delete:\s*if false"))

Add ("public_profiles client write blocked = " +
    [bool]($fr -match "match /public_profiles/\{uid\}[\s\S]{0,300}allow create, update, delete:\s*if false"))

Add ("activeSessionId user editable = " +
    [bool]($fr -match "function userEditableFieldsOnly[\s\S]{0,1200}activeSessionId"))

Add ("firestore default deny = " +
    [bool]($fr -match "match /\{document=\*\*\}[\s\S]{0,200}allow read, write:\s*if false"))

Add "===== STORAGE RULES ====="

$sr = Get-Content .\storage.rules -Raw

Add ("verification_documents rule = " +
    [bool]($sr -match "verification_documents"))

Add ("profile_photos rule = " +
    [bool]($sr -match "profile_photos"))

Add ("storage default deny = " +
    [bool]($sr -match "match /\{allPaths=\*\*\}[\s\S]{0,200}allow read, write:\s*if false"))

Add "===== OLD RISK FILES ====="

Add ("payment_service.dart = " +
    (Test-Path .\lib\services\payment_service.dart))

Add ("assertModerator.ts = " +
    (Test-Path .\functions\src\security\assertModerator.ts))

Add ("updateUserStatus.ts = " +
    (Test-Path .\functions\src\users\updateUserStatus.ts))

$out | Set-Content $report -Encoding UTF8

Write-Host ""
Write-Host "TAMAM. RAPOR:" -ForegroundColor Green
Write-Host $report -ForegroundColor Yellow
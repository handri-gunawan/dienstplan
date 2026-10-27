# Dienstplan verschluesseln und auf GitHub Pages veroeffentlichen.
# Aufruf:  powershell -ExecutionPolicy Bypass -File veroeffentlichen.ps1
#          ... -NurBauen   (nur index.html erzeugen, nichts hochladen)
# Das Passwort wird abgefragt (oder aus $env:STATICRYPT_PASSWORD gelesen).
# Es wird nirgends gespeichert.
param(
  [string]$Quelle = (Join-Path $env:USERPROFILE "Dropbox\documents\JKEB\Dienstplan.html"),
  [switch]$NurBauen
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path $Quelle)) { throw "Quelle nicht gefunden: $Quelle" }

$gesetzt = $false
if (-not $env:STATICRYPT_PASSWORD) {
  $s = Read-Host "Passwort fuer den Dienstplan" -AsSecureString
  $env:STATICRYPT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
  $gesetzt = $true
}

try {
  $tmp = Join-Path $PSScriptRoot "_build"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

  # Salt liegt in .staticrypt.json (wird beim ersten Lauf angelegt und danach
  # wiederverwendet), damit "Passwort merken" auf dem iPhone Updates uebersteht.
  npx --yes staticrypt@3 $Quelle -d $tmp --short --remember 365 `
    --template-title "Dienstplan JKEB" `
    --template-instructions "Bitte das Passwort eingeben." `
    --template-placeholder "Passwort" `
    --template-button "Anzeigen" `
    --template-remember "Passwort merken" `
    --template-error "Falsches Passwort." `
    --template-toggle-show "Passwort zeigen" `
    --template-toggle-hide "Passwort verbergen" `
    --template-color-primary "#2B3F7A" `
    --template-color-secondary "#E7EAF1"
  if ($LASTEXITCODE -ne 0) { throw "staticrypt fehlgeschlagen" }
}
finally {
  if ($gesetzt) { Remove-Item Env:STATICRYPT_PASSWORD -ErrorAction SilentlyContinue }
}

Move-Item (Join-Path $tmp (Split-Path $Quelle -Leaf)) (Join-Path $PSScriptRoot "index.html") -Force
Remove-Item $tmp -Recurse -Force

node tools\inject-head.js $Quelle index.html
if ($LASTEXITCODE -ne 0) { throw "inject-head fehlgeschlagen" }

# Sicherheitsnetz: in index.html darf kein Klartext aus dem Plan stehen.
foreach ($w in @("Geburtstag", "Sonntagschule", "Konsumsi", "Hauskreis")) {
  if (Select-String -Path index.html -Pattern $w -SimpleMatch -Quiet) {
    throw "index.html enthaelt Klartext ('$w') - Abbruch, nichts hochgeladen."
  }
}
Write-Host "index.html verschluesselt erzeugt."

if ($NurBauen) { return }

git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "Keine Aenderung - nichts hochzuladen."; return }
git commit -m ("Dienstplan aktualisiert " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
git push
if ($LASTEXITCODE -ne 0) { throw "git push fehlgeschlagen" }
Write-Host "Hochgeladen. Die Seite ist nach ca. 1-2 Minuten aktuell:"
Write-Host "https://handri-gunawan.github.io/dienstplan/"

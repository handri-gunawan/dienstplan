# Dienstplan verschluesseln und auf GitHub Pages veroeffentlichen.
# Aufruf:  powershell -ExecutionPolicy Bypass -File veroeffentlichen.ps1
#          ... -NurBauen        (nur index.html erzeugen, nichts hochladen)
#          ... -NeuesPasswort   (Passwort absichtlich wechseln; ueberspringt die
#                                Pruefung gegen die bisherige Seite)
# Das Passwort wird abgefragt (oder aus $env:STATICRYPT_PASSWORD gelesen).
# Es wird nirgends gespeichert.
param(
  [string]$Quelle = (Join-Path $env:USERPROFILE "Dropbox\documents\JKEB\Dienstplan.html"),
  [switch]$NurBauen,
  [switch]$NeuesPasswort
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path $Quelle)) { throw "Quelle nicht gefunden: $Quelle" }

function Lies([string]$frage) {
  $s = Read-Host $frage -AsSecureString
  [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

# Prueft, ob das Passwort in $env:STATICRYPT_PASSWORD die zuletzt hochgeladene
# Seite (index.html im letzten Commit) entschluesselt.
# Rueckgabe: $true = passt, $false = passt nicht, $null = keine Seite vorhanden.
function PasstZurBisherigenSeite {
  $pruef = Join-Path $PSScriptRoot "_pruefung"
  if (Test-Path $pruef) { Remove-Item $pruef -Recurse -Force }
  New-Item -ItemType Directory -Path $pruef | Out-Null
  try {
    $alt = Join-Path $pruef "bisher.html"
    # ueber cmd: Umleitung bytegenau, Meldungen auf stderr loesen keinen Abbruch aus
    cmd /c "git show HEAD:index.html > `"$alt`" 2>nul"
    if ($LASTEXITCODE -ne 0 -or (Get-Item $alt).Length -eq 0) { return $null }
    $aus = Join-Path $pruef "aus"
    cmd /c "npx --yes staticrypt@3 `"$alt`" --decrypt -d `"$aus`" >nul 2>&1"
    $klartext = Join-Path $aus "bisher.html"
    return [bool]((Test-Path $klartext) -and
      (Select-String -Path $klartext -Pattern "Hauskreis" -SimpleMatch -Quiet))
  }
  finally {
    if (Test-Path $pruef) { Remove-Item $pruef -Recurse -Force }
  }
}

$gesetzt = $false
if (-not $env:STATICRYPT_PASSWORD) {
  $p1 = Lies "Passwort fuer den Dienstplan"
  $p2 = Lies "Passwort wiederholen"
  if (-not $p1 -or $p1 -ne $p2) {
    throw "Die beiden Eingaben stimmen nicht ueberein - nichts hochgeladen."
  }
  $env:STATICRYPT_PASSWORD = $p1
  $p1 = $null; $p2 = $null
  $gesetzt = $true
}

try {
  if ($NeuesPasswort) {
    Write-Host "Hinweis: Passwort wird gewechselt. Auf allen Geraeten muss das neue Passwort eingegeben werden."
  }
  else {
    Write-Host "Pruefe Passwort gegen die bisherige Seite ..."
    $passt = PasstZurBisherigenSeite
    if ($passt -eq $false) {
      throw ("Das Passwort passt nicht zur bisher veroeffentlichten Seite - nichts hochgeladen. " +
             "Bitte erneut versuchen. Nur wenn das Passwort absichtlich gewechselt werden soll: " +
             "veroeffentlichen.ps1 -NeuesPasswort")
    }
    if ($passt) { Write-Host "Passwort stimmt." }
    else { Write-Host "Keine bisherige Seite gefunden - Pruefung entfaellt." }
  }

  $tmp = Join-Path $PSScriptRoot "_build"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Path (Join-Path $tmp "src") | Out-Null
  $app = Join-Path $tmp "src\Dienstplan.html"

  # App-Verhalten (Sprung zum aktuellen Wochenende, eigenes Symbol) ergaenzen
  node tools\inject-app.js $Quelle $app
  if ($LASTEXITCODE -ne 0) { throw "inject-app fehlgeschlagen" }

  # Salt liegt in .staticrypt.json (wird beim ersten Lauf angelegt und danach
  # wiederverwendet), damit "Passwort merken" auf dem iPhone Updates uebersteht.
  npx --yes staticrypt@3 $app -d (Join-Path $tmp "out") --short --remember 365 `
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

Move-Item (Join-Path $tmp "out\Dienstplan.html") (Join-Path $PSScriptRoot "index.html") -Force

node tools\inject-head.js $app index.html
if ($LASTEXITCODE -ne 0) { throw "inject-head fehlgeschlagen" }
Remove-Item $tmp -Recurse -Force

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

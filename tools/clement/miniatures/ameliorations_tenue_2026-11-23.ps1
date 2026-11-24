# Les 15 miniatures du 2026-11-23 avec la vraie tenue du bacon hair (MOD-043) : memes reglages que
# ameliorations_2026-11-23.ps1 (argent, fleche de Clement, "!!"), mais chaque image de base est la version refaite par
# ChatGPT avec la tenue de reference (finales/v_tenue/chatgpt/<nn>_tenue.png). Voir finales/v_tenue/note.md.
# Usage, depuis la racine du depot (PowerShell) :
#   powershell -ExecutionPolicy Bypass -File tools/clement/miniatures/ameliorations_tenue_2026-11-23.ps1
#   & tools/clement/miniatures/ameliorations_tenue_2026-11-23.ps1 -Seulement '01','04'   (avec -File, "01,04" arrive en un seul texte et rien n'est fait)
# Les valeurs d'argent sont volontairement gonflees, a la demande de Clement : ce ne sont pas des valeurs du jeu.
param(
  [string]$Sortie = 'docs/claude/miniatures/2026-11-23_ameliorations/finales/v_tenue',
  [string]$Source = 'docs/claude/miniatures/2026-11-23_ameliorations/finales/v_tenue/chatgpt',
  [string[]]$Seulement = @()
)
$ErrorActionPreference = 'Stop'
$b = 'docs/claude/miniatures/2026-11-23_ameliorations'
$c = "$b/chatgpt"
$fl = 'docs/claude/miniatures/elements/fleche_rouge_clement.png'
function Orig([string]$n) { (Get-ChildItem "$b/originaux/$($n)_*.png" | Select-Object -First 1).FullName }

# FLECHE_IMAGE = "image|centre x|centre y|plus grand cote|rotation en degres (sens inverse des aiguilles)|miroir"
# EXCLAMATION = "centre x,centre y,corps,angle"
$travaux = @(
  @{ n = '01'; nom = 'THUMB_01_CasseDiscret.png'; src = ''; env = @{
      ETIQUETTE = '|||+$548B/s'; ETIQUETTE_CENTRE = '1010,320'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1345|380|240|50|1" } },
  # 03 : pas de fleche, le doigt du vigile pointe deja la scene
  @{ n = '03'; nom = 'THUMB_03_CasseRepere.png'; src = ''; env = @{
      ETIQUETTE = '|||+$548B/s'; ETIQUETTE_CENTRE = '985,250'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  @{ n = '02'; nom = 'THUMB_02_FuiteCouronne.png'; src = ''; env = @{
      ETIQUETTE = '|||+$457.8B/s'; ETIQUETTE_CENTRE = '1450,225'; ETIQUETTE_TAILLES = '54,40,40,112'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1815|330|240|55|1"; EXCLAMATION = '600,260,150,-10' } },
  @{ n = '16'; nom = 'THUMB_16_FuiteCouronneVigile.png'; src = ''; env = @{
      ETIQUETTE = '|||+$548B/s'; ETIQUETTE_CENTRE = '1520,230'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1840|330|220|55|1" } },
  @{ n = '11'; nom = 'THUMB_11_FuiteGrosPlan.png'; src = ''; env = @{
      ETIQUETTE = '|||+$458B/s'; ETIQUETTE_CENTRE = '1630,160'; ETIQUETTE_TAILLES = '54,40,40,92'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1780|390|220|-80|0" } },
  @{ n = '04'; nom = 'THUMB_04_Casse.png'; src = ''; env = @{
      ETIQUETTE = '|||+$48.7B/s'; ETIQUETTE_CENTRE = '1570,238'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1190|290|280|-50|0" } },
  @{ n = '37'; nom = 'THUMB_37_CasseVitrine.png'; src = ''; env = @{
      ETIQUETTE = '|||+$48.7B/s'; ETIQUETTE_CENTRE = '1600,240'; ETIQUETTE_TAILLES = '54,40,40,110'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1300|290|260|-45|0" } },
  @{ n = '07'; nom = 'THUMB_07_FuiteOeuf.png'; src = ''; env = @{
      ETIQUETTE = '|||+$958B/s'; ETIQUETTE_CENTRE = '520,230'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|980|95|260|-12|0" } },
  # 18 : pas de fleche, la tete du voleur monte jusqu'en haut de l'image
  @{ n = '18'; nom = 'THUMB_18_FuiteOeufBoutique.png'; src = ''; env = @{
      ETIQUETTE = '|||+$958B/s'; ETIQUETTE_CENTRE = '520,200'; ETIQUETTE_TAILLES = '54,40,40,110'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  @{ n = '05'; nom = 'THUMB_05_MarteauNiveaux.png'; src = ''; env = @{
      FLECHE_IMAGE = "$fl|925|215|380|0|0" } },
  @{ n = '08'; nom = 'THUMB_08_MarteauAvantApres.png'; src = ''; env = @{
      FLECHE_IMAGE = "$fl|850|140|460|-10|0" } },
  @{ n = '06'; nom = 'THUMB_06_PoursuitePC.png'; src = ''; env = @{
      ETIQUETTE = '|||+$63.2B/s'; ETIQUETTE_CENTRE = '560,228'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|200|340|320|-75|0"; EXCLAMATION = '1005,500,165,-10' } },
  @{ n = '31'; nom = 'THUMB_31_PoursuiteTokyo.png'; src = ''; env = @{
      ETIQUETTE = '|||+$63.2B/s'; ETIQUETTE_CENTRE = '1350,200'; ETIQUETTE_TAILLES = '54,40,40,110'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|930|250|260|10|1"; EXCLAMATION = '1140,390,130,-10' } },
  @{ n = '22'; nom = 'THUMB_22_SalleAuxTresors.png'; src = ''; env = @{
      ETIQUETTE = '|||+$1.2T/s'; ETIQUETTE_CENTRE = '1130,215'; ETIQUETTE_TAILLES = '54,40,40,120'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|740|220|240|-50|0" } },
  @{ n = '26'; nom = 'THUMB_26_Boutique.png'; src = ''; env = @{
      ETIQUETTE = '|||+$1.2T/s'; ETIQUETTE_CENTRE = '960,175'; ETIQUETTE_TAILLES = '54,40,40,130'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1110|290|200|50|1" } }
)

$vars = 'ETIQUETTE', 'ETIQUETTE_CENTRE', 'ETIQUETTE_TAILLES', 'ETIQUETTE_ARC_EN_CIEL', 'ETIQUETTE_RARETE', 'FLECHE_IMAGE',
        'EXCLAMATION', 'FLECHE', 'FLECHE_ARC', 'FLECHE_TETE', 'RETOUCHE'
New-Item -ItemType Directory -Force $Sortie | Out-Null
foreach ($t in $travaux) {
  if ($Seulement.Count -and -not ($Seulement -contains $t.n)) { continue }
  $t.src = "$Source/$($t.n)_tenue.png"
  if (-not (Test-Path $t.src)) { Write-Host "pas encore d'image pour $($t.n)"; continue }
  foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
  foreach ($k in $t.env.Keys) { Set-Item "Env:$k" $t.env[$k] }
  py -I tools/clement/miniatures/miniature_ia.py $t.src $Sortie - haut-droite $t.nom
  if ($LASTEXITCODE -ne 0) { throw "echec sur la miniature $($t.n)" }
}
foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }

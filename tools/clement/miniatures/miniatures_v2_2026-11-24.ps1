# Miniatures v2 du 2026-11-24 (MOD-043) : pose l'argent (etiquette BB_Item, 50 % plus gros qu'avant, texte court) et la
# fleche rouge de Clement sur les 6 images refaites par ChatGPT (voir docs/claude/miniatures/2026-11-24_v2/note.md).
# Usage, depuis la racine du depot (PowerShell) :
#   & tools/clement/miniatures/miniatures_v2_2026-11-24.ps1
#   & tools/clement/miniatures/miniatures_v2_2026-11-24.ps1 -Seulement '07','31'
# Les valeurs d'argent sont volontairement gonflees, a la demande de Clement : ce ne sont pas des valeurs du jeu.
param(
  [string]$Sortie = 'docs/claude/miniatures/2026-11-24_v2',
  [string]$Source = 'docs/claude/miniatures/2026-11-24_v2/chatgpt',
  [string[]]$Seulement = @()
)
$ErrorActionPreference = 'Stop'
$fl = 'docs/claude/miniatures/elements/fleche_rouge_clement.png'
# corps du revenu : 180 px (120 px dans la v1, soit 50 % de plus)

# FLECHE_IMAGE = "image|centre x|centre y|plus grand cote|rotation en degres (sens inverse des aiguilles)|miroir"
$travaux = @(
  @{ n = '07'; nom = 'THUMB_07_FuiteDragon.png'; env = @{
      ETIQUETTE = '|||+$5T/s'; ETIQUETTE_CENTRE = '470,250'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1000|90|240|-12|0" } },
  # 26 et 22 : l'argent est juste au-dessus du coffre, pas de place pour une fleche sans couvrir la tete du braqueur
  @{ n = '26'; nom = 'THUMB_26_FuiteCoffreBoutique.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '1600,170'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  @{ n = '22'; nom = 'THUMB_22_FuiteCoffre.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '1540,200'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  # 08 : un seul perso ; l'argent au-dessus de la Couronne, derriere la vitre
  @{ n = '08'; nom = 'THUMB_08_Marteau.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '1600,330'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  # 18 : pas de fleche, la tete du braqueur est entre l'argent et l'oeuf
  @{ n = '18'; nom = 'THUMB_18_FuiteOeuf.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '360,175'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  @{ n = '31'; nom = 'THUMB_31_PoursuiteTokyo.png'; env = @{
      ETIQUETTE = '|||+$63B/s'; ETIQUETTE_CENTRE = '1290,230'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1010|330|220|-15|1" } }
)

$vars = 'ETIQUETTE', 'ETIQUETTE_CENTRE', 'ETIQUETTE_TAILLES', 'ETIQUETTE_ARC_EN_CIEL', 'ETIQUETTE_RARETE', 'FLECHE_IMAGE',
        'EXCLAMATION', 'FLECHE', 'FLECHE_ARC', 'FLECHE_TETE', 'RETOUCHE'
New-Item -ItemType Directory -Force $Sortie | Out-Null
foreach ($t in $travaux) {
  if ($Seulement.Count -and -not ($Seulement -contains $t.n)) { continue }
  $src = "$Source/$($t.n)_v2.png"
  if (-not (Test-Path $src)) { Write-Host "pas d'image pour $($t.n)"; continue }
  foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
  foreach ($k in $t.env.Keys) { Set-Item "Env:$k" $t.env[$k] }
  py -I tools/clement/miniatures/miniature_ia.py $src $Sortie - haut-droite $t.nom
  if ($LASTEXITCODE -ne 0) { throw "echec sur la miniature $($t.n)" }
}
foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }

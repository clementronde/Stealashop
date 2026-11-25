# Miniatures du 2026-11-25 (MOD-043), faites avec le prompt docs/claude/miniatures/prompt_miniatures.md : pose l'argent
# (etiquette BB_Item, corps 180 px), la fleche rouge de Clement et les "!!" du vigile sur les 6 images de ChatGPT
# (voir docs/claude/miniatures/2026-11-25_prompt/note.md).
# Usage, depuis la racine du depot (PowerShell) :
#   & tools/clement/miniatures/miniatures_prompt_2026-11-25.ps1
#   & tools/clement/miniatures/miniatures_prompt_2026-11-25.ps1 -Seulement '1','3'
# Les valeurs d'argent sont volontairement gonflees, a la demande de Clement : ce ne sont pas des valeurs du jeu.
param(
  [string]$Sortie = 'docs/claude/miniatures/2026-11-25_prompt',
  [string]$Source = 'docs/claude/miniatures/2026-11-25_prompt/chatgpt',
  [string[]]$Seulement = @()
)
$ErrorActionPreference = 'Stop'
$fl = 'docs/claude/miniatures/elements/fleche_rouge_clement.png'

# FLECHE_IMAGE = "image|centre x|centre y|plus grand cote|rotation en degres (sens inverse des aiguilles)|miroir"
# EXCLAMATION = "centre x,centre y,corps,angle"
$travaux = @(
  @{ n = '1'; nom = 'THUMB_P1_CasseGuitareLA.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '1570,195'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1580|380|220|45|1" } },
  # 2 : pas de fleche, la tete du braqueur est entre l'argent et le Croissant requin
  @{ n = '2'; nom = 'THUMB_P2_ColisCroissantParis.png'; env = @{
      ETIQUETTE = '|||+$5T/s'; ETIQUETTE_CENTRE = '370,190'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      EXCLAMATION = '150,380,110,-10' } },
  @{ n = '3'; nom = 'THUMB_P3_FuitePigeonNewYork.png'; env = @{
      ETIQUETTE = '|||+$9T/s'; ETIQUETTE_CENTRE = '1570,210'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1500|320|200|45|1"; EXCLAMATION = '200,250,120,-10' } },
  # 4 : pas de fleche (tete du braqueur entre les deux) ni de "!!" (c'est un joueur, pas un vigile)
  @{ n = '4'; nom = 'THUMB_P4_VolJoueurCapybara.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '360,220'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1' } },
  # 5 : pas de "!!", les vigiles de nuit ne l'ont pas encore vu
  @{ n = '5'; nom = 'THUMB_P5_NuitChihuahuaLondres.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '1570,210'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|1180|200|200|15|1" } },
  @{ n = '6'; nom = 'THUMB_P6_EntrainementLingot.png'; env = @{
      ETIQUETTE = '|||+$1T/s'; ETIQUETTE_CENTRE = '360,210'; ETIQUETTE_TAILLES = '54,40,40,180'; ETIQUETTE_ARC_EN_CIEL = '1'
      FLECHE_IMAGE = "$fl|700|300|200|-10|0" } }
)

$vars = 'ETIQUETTE', 'ETIQUETTE_CENTRE', 'ETIQUETTE_TAILLES', 'ETIQUETTE_ARC_EN_CIEL', 'ETIQUETTE_RARETE', 'FLECHE_IMAGE',
        'EXCLAMATION', 'FLECHE', 'FLECHE_ARC', 'FLECHE_TETE', 'RETOUCHE'
New-Item -ItemType Directory -Force $Sortie | Out-Null
foreach ($t in $travaux) {
  if ($Seulement.Count -and -not ($Seulement -contains $t.n)) { continue }
  $src = "$Source/p$($t.n).png"
  if (-not (Test-Path $src)) { Write-Host "pas d'image pour $($t.n)"; continue }
  foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
  foreach ($k in $t.env.Keys) { Set-Item "Env:$k" $t.env[$k] }
  py -I tools/clement/miniatures/miniature_ia.py $src $Sortie - haut-droite $t.nom
  if ($LASTEXITCODE -ne 0) { throw "echec sur la miniature $($t.n)" }
}
foreach ($v in $vars) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }

# L-352 : pose les images validées par Clément (26/11) sur les gamepasses et les produits développeur du Creator Hub,
# par l'API Open Cloud (doc à jour du 24/11/2026) :
#   gamepass : PATCH https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{gamePassId}
#              champ imageFile, scope game-pass:write (BETA)
#   produit  : PATCH https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}
#              champ imageFile, scope developer-product:write (BETA)
# Seule l'image est envoyée : le nom, la description, le prix et la mise en vente ne changent pas (« only fields
# provided in the request will be updated »). Les badges n'ont pas d'API pour leur image principale : à la main.
#
#   Voir ce qui serait fait, sans rien envoyer :  pwsh -File tools\clement\poser_icones_creator_hub.ps1 -Jeu DEV -Essai
#   Jeu DEV :                                     pwsh -File tools\clement\poser_icones_creator_hub.ps1 -Jeu DEV
#   Jeu PROD (seulement avec l'accord de Clément) : pwsh -File tools\clement\poser_icones_creator_hub.ps1 -Jeu PROD
#
# La clé API est demandée au lancement, sans s'afficher ni s'enregistrer. Elle doit avoir les scopes game-pass:write
# et developer-product:write pour le jeu visé. Rejouable : ce qui est déjà posé (noté dans le CSV) est sauté.
#   Reposer une offre déjà faite :               ... -Jeu DEV -Refaire DoubleTraining
param(
    [Parameter(Mandatory = $true)][ValidateSet("DEV", "PROD")][string]$Jeu,
    [string]$Dossier = "C:\Users\Charment\Documents\Stealashop\docs\claude\gamepasses\icones\offres_2026-11-26",
    [string[]]$Refaire = @(),
    [switch]$Essai
)

# Universe et Ids : Config/Balance (DevGameId), publication-prod.md (PROD), Config/Monetization (Ids PROD),
# Config/ProductIds (Ids DEV), relus le 26/11 sur origin/main.
$jeux = @{
    DEV  = @{ Universe = 10774974820 }
    PROD = @{ Universe = 10774998269 }
}
$offres = @(
    @{ Cle = "DoubleCash";     Type = "pass";    Image = "UI_Icon_GP_x2Cash.png";       PROD = 2098559046; DEV = 2099561059 },
    # ×2 Training devient ×4 avec Features.TrainingX4 (TrainingX4Dev allumé dans le jeu DEV, coupé en PROD au 26/11) :
    # image ×4 dans DEV. Le jour où TrainingX4 s'allume en PROD, mettre ImagePROD = "UI_Icon_GP_x4Training.png" et
    # relancer avec -Jeu PROD -Refaire DoubleTraining.
    @{ Cle = "DoubleTraining"; Type = "pass";    Image = "UI_Icon_GP_x2Training.png";   ImageDEV = "UI_Icon_GP_x4Training.png"; PROD = 2099849032; DEV = 2098985017 },
    @{ Cle = "DoubleSpeed";    Type = "pass";    Image = "UI_Icon_GP_DoubleSpeed.png";  PROD = 2101984255; DEV = 2099495015 },
    @{ Cle = "AutoCollect";    Type = "pass";    Image = "UI_Icon_GP_AutoCollect.png";  PROD = 2099027027; DEV = 2101906271 },
    @{ Cle = "FastOpen";       Type = "pass";    Image = "UI_Icon_GP_FastOpen.png";     PROD = 2099039016; DEV = 2098265079 },
    @{ Cle = "ExtraStands";    Type = "pass";    Image = "UI_Icon_GP_Displays.png";     PROD = 2099033063; DEV = 2100029033 },
    @{ Cle = "StarterPack";    Type = "product"; Image = "UI_Icon_DP_StarterPack.png";  PROD = 3735788614; DEV = 3735786424 },
    @{ Cle = "Cash10";         Type = "product"; Image = "UI_Icon_DP_Cash_1.png";       PROD = 3735788763; DEV = 3735787184 },
    @{ Cle = "Cash30";         Type = "product"; Image = "UI_Icon_DP_Cash_2.png";       PROD = 3735788830; DEV = 3735787374 },
    @{ Cle = "Cash60";         Type = "product"; Image = "UI_Icon_DP_Cash_3.png";       PROD = 3735788938; DEV = 3735787436 },
    @{ Cle = "Cash180";        Type = "product"; Image = "UI_Icon_DP_Cash_4.png";       PROD = 3735789144; DEV = 3735787830 },
    @{ Cle = "Cash300";        Type = "product"; Image = "UI_Icon_DP_Cash_5.png";       PROD = 3735789195; DEV = 3735787886 },
    @{ Cle = "Cash720";        Type = "product"; Image = "UI_Icon_DP_Cash_6.png";       PROD = 3735789566; DEV = 3735788027 },
    @{ Cle = "OpenNow1";       Type = "product"; Image = "UI_Icon_DP_OpenNow.png";      PROD = 3735789930; DEV = 3735788091 },
    @{ Cle = "OpenNow2";       Type = "product"; Image = "UI_Icon_DP_OpenNow.png";      PROD = 3735790062; DEV = 3735788288 },
    # Paliers 3 et 4 : vente coupée, jamais supprimés ; on leur pose la même image pour qu'un reçu en attente reste propre.
    @{ Cle = "OpenNow3";       Type = "product"; Image = "UI_Icon_DP_OpenNow.png";      PROD = 3735790266; DEV = 3735788351 },
    @{ Cle = "OpenNow4";       Type = "product"; Image = "UI_Icon_DP_OpenNow.png";      PROD = 3735790374; DEV = 3735788532 }
)

$universe = $jeux[$Jeu].Universe
$csv = Join-Path $Dossier "creator_hub_$($Jeu.ToLower()).csv"
$fait = @{}
if (Test-Path $csv) { Import-Csv $csv | ForEach-Object { if ($_.Statut -eq "OK") { $fait[$_.Cle] = $true } } }
foreach ($k in $Refaire) { $fait.Remove($k) }
# Image propre à un jeu (ImageDEV, ImagePROD), sinon Image.
foreach ($o in $offres) { if ($o.ContainsKey("Image$Jeu")) { $o.Image = $o["Image$Jeu"] } }

Write-Host "Jeu $Jeu (universe $universe) : $($offres.Count) offres, image seulement."
foreach ($o in $offres) {
    $chemin = Join-Path $Dossier $o.Image
    $etatTxt = if ($fait[$o.Cle]) { "déjà posée" } elseif (-not (Test-Path $chemin)) { "IMAGE ABSENTE" } else { "à poser" }
    Write-Host ("  {0,-15} {1,-8} {2,-12} {3,-30} {4}" -f $o.Cle, $o.Type, $o[$Jeu], $o.Image, $etatTxt)
}
if ($Essai) { Write-Host "Essai : rien n'est envoyé." -ForegroundColor Yellow; exit 0 }

if ($Jeu -eq "PROD") {
    $ok = Read-Host "PROD : tape exactement OUI PROD si Clément a donné son accord pour ce jeu"
    if ($ok -ne "OUI PROD") { Write-Host "Pas d'accord tapé, rien n'est envoyé." -ForegroundColor Red; exit 1 }
} else {
    $ok = Read-Host "DEV : tape OUI pour poser ces images"
    if ($ok -ne "OUI") { Write-Host "Rien n'est envoyé." -ForegroundColor Red; exit 1 }
}

$secure = Read-Host "Clé API Open Cloud (game-pass:write et developer-product:write)" -AsSecureString
$cle = [System.Net.NetworkCredential]::new("", $secure).Password
if ([string]::IsNullOrWhiteSpace($cle)) { Write-Host "Pas de clé, rien n'est envoyé." -ForegroundColor Red; exit 1 }

$client = [System.Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Add("x-api-key", $cle)
$journal = [System.Collections.Generic.List[object]]::new()
if (Test-Path $csv) { Import-Csv $csv | ForEach-Object { $journal.Add($_) } }

foreach ($o in $offres) {
    if ($fait[$o.Cle]) { continue }
    $chemin = Join-Path $Dossier $o.Image
    if (-not (Test-Path $chemin)) { Write-Host "image absente : $chemin" -ForegroundColor Red; continue }
    $id = $o[$Jeu]
    $url = if ($o.Type -eq "pass") {
        "https://apis.roblox.com/game-passes/v1/universes/$universe/game-passes/$id"
    } else {
        "https://apis.roblox.com/developer-products/v2/universes/$universe/developer-products/$id"
    }
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $contenu = [System.Net.Http.ByteArrayContent]::new([System.IO.File]::ReadAllBytes($chemin))
    $contenu.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new("image/png")
    $form.Add($contenu, "imageFile", $o.Image)
    $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Patch, $url)
    $req.Content = $form
    $rep = $client.SendAsync($req).Result
    $txt = $rep.Content.ReadAsStringAsync().Result
    $code = [int]$rep.StatusCode
    $statut = if ($rep.IsSuccessStatusCode) { "OK" } else { "ERREUR $code" }
    if ($rep.IsSuccessStatusCode) { Write-Host "OK $($o.Cle) ($id)" -ForegroundColor Green }
    else { Write-Host "ERREUR $($o.Cle) ($id) : $code $txt" -ForegroundColor Red }
    $journal.Add([pscustomobject]@{ Cle = $o.Cle; Type = $o.Type; Id = $id; Image = $o.Image; Statut = $statut; Date = (Get-Date -Format "yyyy-MM-dd HH:mm") })
    $journal | Export-Csv $csv -NoTypeInformation -Encoding utf8
    if ($code -eq 401 -or $code -eq 403) { Write-Host "Clé refusée ou scope manquant : arrêt." -ForegroundColor Red; break }
    if ($code -eq 429) { Write-Host "trop de requêtes, pause de 30 s" -ForegroundColor Yellow; Start-Sleep -Seconds 30 }
    Start-Sleep -Milliseconds 500
}
$client.Dispose()
$cle = $null
Write-Host "Journal : $csv"

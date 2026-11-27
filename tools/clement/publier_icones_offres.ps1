# L-352 : publie les images des offres et des badges (UI_Icon_GP_*, UI_Icon_DP_*, BADGE_*) au nom du groupe
# RoundStone Studio, par l'API Open Cloud (Assets, type Decal), et note chaque ID dans un CSV à côté des PNG.
# Même façon de faire que StealAShop-Art/FX/_src/publier_fx.ps1 : la clé API est demandée au lancement, sans
# s'afficher ni s'enregistrer nulle part.
#
#   Essai sur un seul fichier :  pwsh -File tools\clement\publier_icones_offres.ps1 -Limite 1
#   Tout le reste :              pwsh -File tools\clement\publier_icones_offres.ps1
#   Sans les badges :            pwsh -File tools\clement\publier_icones_offres.ps1 -SansBadges
#
# Rejouable : une image déjà publiée (ID dans le CSV) est sautée ; une opération restée en attente est seulement
# relue, jamais renvoyée (pas de doublon).
# À la fin, le script écrit poser_decals_offres.luau dans le même dossier : à lancer en Edit dans Studio, il donne
# la nouvelle image aux Decals de ReplicatedStorage/Assets/Icons (jamais renommés ni supprimés).
param(
    [string]$Dossier = "C:\Users\Charment\Documents\Stealashop\docs\claude\gamepasses\icones\offres_2026-11-26",
    [string]$Csv = "",
    [string]$GroupId = "207192094",
    [int]$Limite = 0,
    [switch]$SansBadges
)

if (-not $Csv) { $Csv = Join-Path $Dossier "icones_offres_ids.csv" }
$filtres = @("UI_Icon_GP_*.png", "UI_Icon_DP_*.png")
if (-not $SansBadges) { $filtres += "BADGE_*.png" }
$fichiers = $filtres | ForEach-Object { Get-ChildItem $Dossier -Filter $_ } | Sort-Object Name
if ($fichiers.Count -eq 0) { Write-Host "Aucune image trouvée dans $Dossier" -ForegroundColor Red; exit 1 }
Write-Host "$($fichiers.Count) images trouvées dans $Dossier"

$secure = Read-Host "Clé API Open Cloud du groupe (Assets API : lecture + écriture)" -AsSecureString
$cle = [System.Net.NetworkCredential]::new("", $secure).Password
if ([string]::IsNullOrWhiteSpace($cle)) { Write-Host "Pas de clé, rien n'est envoyé." -ForegroundColor Red; exit 1 }

$etat = @{}
if (Test-Path $Csv) { Import-Csv $Csv | ForEach-Object { $etat[$_.ItemId] = $_ } }

$client = [System.Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Add("x-api-key", $cle)

function Lire-Operation([string]$opId) {
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        $rep = $client.GetAsync("https://apis.roblox.com/assets/v1/operations/$opId").Result
        $txt = $rep.Content.ReadAsStringAsync().Result
        if (-not $rep.IsSuccessStatusCode) { Write-Host "  lecture $opId : $($rep.StatusCode) $txt" -ForegroundColor Yellow; continue }
        $r = $txt | ConvertFrom-Json
        if ($r.done) { return $r.response.assetId }
    }
    return $null
}

function Noter([string]$itemId, [string]$assetId, [string]$opId) {
    $etat[$itemId] = [pscustomobject]@{ ItemId = $itemId; AssetId = $assetId; Operation = $opId }
    $etat.Values | Sort-Object ItemId | Export-Csv $Csv -NoTypeInformation -Encoding utf8
}

$faits = 0
foreach ($f in $fichiers) {
    if ($Limite -gt 0 -and $faits -ge $Limite) { break }
    $itemId = $f.BaseName
    $ligne = $etat[$itemId]
    if ($ligne -and $ligne.AssetId) { Write-Host "déjà publiée : $itemId -> $($ligne.AssetId)"; continue }
    if ($ligne -and $ligne.Operation) {
        $assetId = Lire-Operation $ligne.Operation
        if ($assetId) { Noter $itemId $assetId $ligne.Operation; Write-Host "OK $itemId -> $assetId" -ForegroundColor Green }
        else { Write-Host "toujours en attente : $itemId ($($ligne.Operation))" -ForegroundColor Yellow }
        $faits++
        continue
    }
    $requete = @{
        assetType = "Decal"
        displayName = $itemId
        description = "Steal a Shop, icône d'offre ou de badge $itemId"
        creationContext = @{ creator = @{ groupId = $GroupId } }
    } | ConvertTo-Json -Depth 5 -Compress
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $form.Add([System.Net.Http.StringContent]::new($requete), "request")
    $contenu = [System.Net.Http.ByteArrayContent]::new([System.IO.File]::ReadAllBytes($f.FullName))
    $contenu.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new("image/png")
    $form.Add($contenu, "fileContent", $f.Name)
    $rep = $client.PostAsync("https://apis.roblox.com/assets/v1/assets", $form).Result
    $txt = $rep.Content.ReadAsStringAsync().Result
    $faits++
    if (-not $rep.IsSuccessStatusCode) {
        Write-Host "ERREUR $itemId : $([int]$rep.StatusCode) $txt" -ForegroundColor Red
        if ([int]$rep.StatusCode -eq 401 -or [int]$rep.StatusCode -eq 403) { break }
        if ([int]$rep.StatusCode -eq 429) { Write-Host "  trop de requêtes, pause de 30 s" -ForegroundColor Yellow; Start-Sleep -Seconds 30 }
        continue
    }
    $opId = (($txt | ConvertFrom-Json).path -split '/')[-1]
    Noter $itemId "" $opId
    $assetId = Lire-Operation $opId
    if ($assetId) { Noter $itemId $assetId $opId; Write-Host "OK $itemId -> $assetId" -ForegroundColor Green }
    else { Write-Host "en attente : $itemId ($opId), relance le script plus tard" -ForegroundColor Yellow }
    Start-Sleep -Milliseconds 500
}
$client.Dispose()
$cle = $null
Write-Host "IDs notés dans $Csv"

# Script de Studio : seulement les UI_Icon_GP_* et UI_Icon_DP_* publiés (les BADGE_* ne vont pas dans le jeu :
# Config/Badges.Image n'est pas lu par le code).
$lignes = $etat.Values | Where-Object { $_.AssetId -and $_.ItemId -match '^UI_Icon_(GP|DP)_' } | Sort-Object ItemId
if ($lignes.Count -gt 0) {
    $table = ($lignes | ForEach-Object { "`t$($_.ItemId) = $($_.AssetId)," }) -join "`n"
    $luau = @"
--!nocheck
-- L-352 : donne les nouvelles images aux Decals des offres dans ReplicatedStorage/Assets/Icons.
-- Écrit par tools/clement/publier_icones_offres.ps1 (ID des Decals publiés au nom du groupe). À lancer en Edit.
-- Un Decal du même nom reçoit l'image (Texture), jamais renommé ni supprimé ; son ancienne image est gardée dans
-- l'attribut TextureAvant (une seule fois) pour revenir en arrière. Un nom absent (UI_Icon_GP_DoubleSpeed) est créé.
-- Ne crée aucun script.
local DECALS = {
$table
}
local InsertService = game:GetService("InsertService")
local dossier = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Icons")
local faits, crees, rates = 0, 0, {}
for nom, decalId in DECALS do
	local ok, modele = pcall(function() return InsertService:LoadAsset(decalId) end)
	local source = ok and modele and modele:FindFirstChildWhichIsA("Decal", true)
	if not source then
		table.insert(rates, nom)
	else
		local cible = dossier:FindFirstChild(nom)
		if not cible then
			cible = Instance.new("Decal")
			cible.Name = nom
			cible.Parent = dossier
			crees += 1
		elseif cible:GetAttribute("TextureAvant") == nil then
			cible:SetAttribute("TextureAvant", cible.Texture)
		end
		cible.Texture = source.Texture
		faits += 1
	end
	if modele then modele:Destroy() end
end
print(("Icônes des offres : %d mises à jour, dont %d créées ; ratées : %s"):format(faits, crees, table.concat(rates, ", ")))
"@
    $sortie = Join-Path $Dossier "poser_decals_offres.luau"
    Set-Content -Path $sortie -Value $luau -Encoding utf8
    Write-Host "Script de Studio écrit : $sortie"
}

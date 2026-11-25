--!nocheck
-- Catalogue v3 (2026-11-25) : les icônes des 82 nouveaux objets, en Decal ICON_<ItemId> dans
-- ReplicatedStorage/Assets/Icons (même contrat que les icônes v2 : Texture = rbxassetid://<image>).
-- Images : StealAShop-Art/Items/Icons_V3/ICON_<ItemId>.png (512 px, contour #040435), publiées au nom du groupe
-- RoundStone Studio par StealAShop-Art/Items/V3_Meshy/_scripts/publier_icones.ps1 (ID des Decals dans
-- V3_Meshy/icon_ids.csv) ; ci-dessous les ID des images (lus par InsertService:LoadAsset sur chaque Decal).
-- Z4_LunettesDeStar, gardé de la v2, a déjà son icône. À lancer en Edit. Rejouable : un Decal du même nom est
-- seulement mis à jour (Texture), jamais renommé ni supprimé. Ne crée aucun script.

local IMAGES = {
	Secret_ToilettesEnOr = 105476737860093,
	Z1_BananeScotchee = 90969681037986,
	Z1_BoissonSigma = 71012190183697,
	Z1_Canette67 = 107973013877721,
	Z1_ChipsMystere = 73698957357856,
	Z1_ChocolatDeDubai = 107271199763795,
	Z1_GlaceArcEnCiel = 70937044749242,
	Z1_OeufBoudeur = 87312214104556,
	Z1_PastequeMewing = 106893433555998,
	Z1_PouletALunettes = 76382159646373,
	Z1_RamenDeFeu = 97495805216671,
	Z1_SachetSurprise = 76263763065792,
	Z1_SlushieArcEnCiel = 81610115589062,
	Z1_TicketGagnant = 101206716610864,
	Z2_AxolotlEnPeluche = 101903220455291,
	Z2_BarbeAPapaNuage = 77379157927425,
	Z2_BlasterAMousse = 106453628231064,
	Z2_BonbonPiquant = 98641536888900,
	Z2_BusEnGelatine = 137016548413970,
	Z2_CanardRoyal = 98086993080459,
	Z2_CapybaraOrange = 81204556309393,
	Z2_FigurineSurprise = 99158752916337,
	Z2_MachineABonbons = 94902458008864,
	Z2_OursGelifieGeant = 98069115312417,
	Z2_PelucheMonstre = 139898433455305,
	Z2_PopIt = 75162727626241,
	Z2_Slime = 75393942061097,
	Z2_Squishy = 117113833907178,
	Z2_SucetteTourbillon = 131895849165134,
	Z2_TheiereDansante = 124428870789557,
	Z3_AppareilPhotoInstantane = 138579856266008,
	Z3_CasqueOreillesDeChat = 109416458521250,
	Z3_ChatQuiTourne = 119671893997673,
	Z3_ClavierRgb = 132206737577472,
	Z3_EnseigneNeon = 95438659031983,
	Z3_Hoverboard = 138170595900507,
	Z3_LampeALave = 114621446482302,
	Z3_ManetteQuiTranspire = 110399507748513,
	Z3_MicroDeStreamer = 76623190272667,
	Z3_PcGamerQuiFume = 134600504194547,
	Z3_ProjecteurGalaxie = 104120856368750,
	Z3_RobotChien = 137266608816328,
	Z3_SushiNinja = 79835075622554,
	Z3_TelephonePliant = 116084191870640,
	Z4_BasketsEnOr = 117386500604690,
	Z4_BasketsLumineuses = 121143719507962,
	Z4_BraceletDAmitie = 122552946948188,
	Z4_CasquetteAStrass = 127367686488174,
	Z4_ChaineDrip = 98883422494530,
	Z4_ChihuahuaEnDiamants = 87339445368152,
	Z4_FauxOnglesEnOr = 80267824027226,
	Z4_GrillzEnDiamant = 73871626084418,
	Z4_GuitareNeon = 104919359023142,
	Z4_MicroDePopStar = 71314901748124,
	Z4_MontreDiamant = 86488275761202,
	Z4_MontreGlacee = 106210628091706,
	Z4_PerruquePresidentielle = 117457547150078,
	Z4_TropheeDeStar = 99841744952749,
	Z5_BaguetteEnOr = 122557720925469,
	Z5_BeretDeMime = 114858702500834,
	Z5_CramponsDores = 115174471930505,
	Z5_CroissantRequin = 132825740808562,
	Z5_EpeeDansLaPierre = 120648313260802,
	Z5_GoldenBall = 78376681104181,
	Z5_JocondeSelfie = 115894060851070,
	Z5_OeufDeDinoFossile = 95395913828656,
	Z5_OeufDeDragon = 116843921147225,
	Z5_StatueDeChatGeant = 115500718021494,
	Z5_StatueMewing = 94173784031468,
	Z5_TableauPixelArt = 78707828259597,
	Z6_BilletQuiCourt = 123169675478750,
	Z6_CapybaraDore = 94720455825638,
	Z6_CarteNoireInfinie = 132729912191388,
	Z6_CerveauDore = 109879588182007,
	Z6_CoffreADents = 111179402553633,
	Z6_CouronneCosmique = 99920440823806,
	Z6_DragonDeDiamant = 98299569396644,
	Z6_LiberteEnOr = 92541947768548,
	Z6_LingotGeant = 118201562541624,
	Z6_PigeonEnOr = 133235069612586,
	Z6_TaxiEnOr = 71623316705072,
	Z6_ValiseDeBillets = 134399200751158,
}

local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local Icons = Assets:FindFirstChild("Icons")
assert(Icons, "ReplicatedStorage/Assets/Icons introuvable")

local created, updated = 0, 0
for itemId, imageId in IMAGES do
	local name = "ICON_" .. itemId
	local texture = "rbxassetid://" .. imageId
	local decal = Icons:FindFirstChild(name)
	if decal and decal:IsA("Decal") then
		if decal.Texture ~= texture then
			decal.Texture = texture
			updated += 1
		end
	else
		decal = Instance.new("Decal")
		decal.Name = name
		decal.Texture = texture
		decal.Parent = Icons
		created += 1
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Icônes des objets v3")
return string.format("%d Decals créés, %d mis à jour", created, updated)

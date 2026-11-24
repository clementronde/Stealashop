--!nocheck
-- Catalogue d'objets v3 (Clément, 2026-11-24 ; docs/claude/notes/objets-catalogue-v3.md), lot Meshy.
-- À lancer en Edit (barre de commande ou execute_luau). Range les 37 modèles repris de
-- Workspace/_INBOX_CLEMENT/Meshy_Lot2 dans ReplicatedStorage/Assets/Items sous leur nom v3 :
--   - modèle et maillage renommés ITM_<ItemId>, attribut ItemId = nom sans ITM_ ;
--   - l'Animation « Boucle » passe de AnimationController/ à Animations/ (contrat 2.4 : <Modèle>/Animations/<Nom>),
--     un Animator est ajouté dans l'AnimationController ; AnimationId et attribut BoucleAnimationId inchangés ;
--   - l'os « Root » du squelette n'est PAS renommé : renommer un os casse sa piste et celles de ses enfants
--     (vérifié le 24/11 sur ITM_Z6_DragonDeDiamant : ailes immobiles). Voir la liaison.
-- Les 5 objets non repris (en réserve) restent dans Meshy_Lot2. Rejouable : un nom déjà rangé est sauté.

local MAP = {
	-- Zone 1
	ITM_Z1_GlaceArcEnCiel = "Z1_GlaceArcEnCiel",
	ITM_Z1_SlushieArcEnCiel = "Z1_SlushieArcEnCiel",
	ITM_Z1_SachetSurprise = "Z1_SachetSurprise",
	ITM_Z1_RamenDeFeu = "Z1_RamenDeFeu",
	-- Zone 2 (PopIt, Squishy et Slime viennent de la zone 1)
	ITM_Z1_PopIt = "Z2_PopIt",
	ITM_Z1_Squishy = "Z2_Squishy",
	ITM_Z1_Slime = "Z2_Slime",
	ITM_Z2_BarbeAPapaNuage = "Z2_BarbeAPapaNuage",
	ITM_Z2_FigurineSurprise = "Z2_FigurineSurprise",
	ITM_Z2_AxolotlEnPeluche = "Z2_AxolotlEnPeluche",
	ITM_Z2_OursGelifieGeant = "Z2_OursGelifieGeant",
	ITM_Z2_PelucheMonstreADents = "Z2_PelucheMonstre",
	ITM_Z2_BlasterAMousse = "Z2_BlasterAMousse",
	ITM_Z2_MachineABonbons = "Z2_MachineABonbons",
	-- Zone 3
	ITM_Z3_CasqueOreillesDeChat = "Z3_CasqueOreillesDeChat",
	ITM_Z3_RobotChien = "Z3_RobotChien",
	ITM_Z3_LampeALave = "Z3_LampeALave",
	ITM_Z3_AppareilPhotoInstantane = "Z3_AppareilPhotoInstantane",
	ITM_Z3_EnseigneNeon = "Z3_EnseigneNeon",
	ITM_Z3_Hoverboard = "Z3_Hoverboard",
	ITM_Z3_ProjecteurGalaxie = "Z3_ProjecteurGalaxie",
	-- Zone 4
	ITM_Z4_BraceletDAmitie = "Z4_BraceletDAmitie",
	ITM_Z4_CasquetteAStrass = "Z4_CasquetteAStrass",
	ITM_Z4_BasketsLumineuses = "Z4_BasketsLumineuses",
	ITM_Z4_MicroDePopStar = "Z4_MicroDePopStar",
	ITM_Z4_BasketsEnOr = "Z4_BasketsEnOr",
	ITM_Z4_TropheeDeStar = "Z4_TropheeDeStar",
	ITM_Z4_MontreDiamant = "Z4_MontreDiamant",
	ITM_Z4_GuitareNeon = "Z4_GuitareNeon",
	-- Zone 5
	ITM_Z5_TableauPixelArt = "Z5_TableauPixelArt",
	ITM_Z5_EpeeDansLaPierre = "Z5_EpeeDansLaPierre",
	ITM_Z5_OeufDeDinoFossile = "Z5_OeufDeDinoFossile",
	ITM_Z5_StatueDeChatGeant = "Z5_StatueDeChatGeant",
	ITM_Z5_OeufDeDragon = "Z5_OeufDeDragon",
	-- Zone 6 (le capybara doré vient de la zone 5)
	ITM_Z5_CapybaraDore = "Z6_CapybaraDore",
	ITM_Z6_CouronneCosmique = "Z6_CouronneCosmique",
	ITM_Z6_DragonDeDiamant = "Z6_DragonDeDiamant",
}

local lot = workspace:FindFirstChild("_INBOX_CLEMENT") and workspace._INBOX_CLEMENT:FindFirstChild("Meshy_Lot2")
local items = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Items")
assert(lot, "Workspace/_INBOX_CLEMENT/Meshy_Lot2 introuvable")

local done, skipped, missing = {}, {}, {}
for oldName, itemId in MAP do
	local newName = "ITM_" .. itemId
	local model = lot:FindFirstChild(oldName)
	if items:FindFirstChild(newName) then
		table.insert(skipped, newName)
		continue
	end
	if not model then
		table.insert(missing, oldName)
		continue
	end
	local mesh = model:FindFirstChild(oldName)
	if mesh and mesh:IsA("MeshPart") then
		mesh.Name = newName
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		if not controller:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = controller
		end
		local loop = controller:FindFirstChild("Boucle")
		if loop and loop:IsA("Animation") then
			local folder = model:FindFirstChild("Animations") or Instance.new("Folder")
			folder.Name = "Animations"
			folder.Parent = model
			loop.Parent = folder
		end
	end
	model:SetAttribute("ItemId", itemId)
	model.Name = newName
	model.Parent = items
	table.insert(done, newName)
end
table.sort(done)
return string.format("rangés %d, déjà là %d, manquants %d %s", #done, #skipped, #missing, table.concat(missing, ","))

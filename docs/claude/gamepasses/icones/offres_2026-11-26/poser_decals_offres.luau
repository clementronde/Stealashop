--!nocheck
-- L-352 : donne les nouvelles images aux Decals des offres dans ReplicatedStorage/Assets/Icons.
-- Écrit par tools/clement/publier_icones_offres.ps1 (ID des Decals publiés au nom du groupe). À lancer en Edit.
-- Un Decal du même nom reçoit l'image (Texture), jamais renommé ni supprimé ; son ancienne image est gardée dans
-- l'attribut TextureAvant (une seule fois) pour revenir en arrière. Un nom absent (UI_Icon_GP_DoubleSpeed) est créé.
-- Ne crée aucun script.
local DECALS = {
	UI_Icon_DP_Cash_1 = 140334179761909,
	UI_Icon_DP_Cash_2 = 83517619737215,
	UI_Icon_DP_Cash_3 = 112547042413973,
	UI_Icon_DP_Cash_4 = 134036821860590,
	UI_Icon_DP_Cash_5 = 140162872712393,
	UI_Icon_DP_Cash_6 = 87732732114958,
	UI_Icon_DP_OpenNow = 140399630757617,
	UI_Icon_DP_StarterPack = 121275382824156,
	UI_Icon_GP_AutoCollect = 132532097776253,
	UI_Icon_GP_Displays = 74053647930155,
	UI_Icon_GP_DoubleSpeed = 102449923349780,
	UI_Icon_GP_FastOpen = 137953885056000,
	UI_Icon_GP_x2Cash = 131360250807205,
	UI_Icon_GP_x2Training = 104287336396256,
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

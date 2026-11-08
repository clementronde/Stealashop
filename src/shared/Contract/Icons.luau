--!strict
-- Icônes des objets (MOD-040 ; liaison L-055 ; doc 10.3, préfixe ICON) : un Decal ICON_<ItemId>
-- par objet du catalogue (Config/Items), livré par Clément dans ReplicatedStorage/Assets/Icons.
-- Noms et règle de recherche, communs au code (rouleau de l'ouverture des colis, puis UI_Index) et
-- au ContractChecker.
--
-- Règle de recherche, la même que pour les Decals d'auras (L-042) : par le nom, jamais par un ID ;
-- le premier Decal de ce nom (pas le premier objet : un autre objet peut porter le même nom) dont
-- la Texture n'est pas vide ; d'abord dans Assets/Icons, sous-dossiers compris, puis n'importe où
-- sous ReplicatedStorage/Assets. Une icône absente n'est pas une erreur : l'appelant garde son
-- repli (le rouleau montre alors le modèle ITM_ en 3D).
--
-- API (serveur et client) :
--   Icons.Prefix       "ICON_"
--   Icons.Folder       { "Assets", "Icons" } : le dossier des icônes, depuis ReplicatedStorage
--   Icons.name(itemId) -> string         « ICON_<ItemId> »
--   Icons.find(itemId) -> Decal?         le Decal de l'objet, nil s'il n'est pas livré
--   Icons.get(itemId) -> string?         sa Texture (rbxassetid://…), nil s'il n'est pas livré
--   Icons.preload(textures)              télécharge ces textures (ContentProvider) pour qu'elles
--                                        s'affichent tout de suite ; attend la fin du
--                                        téléchargement, donc à lancer dans une tâche ; client
--                                        seulement (ne fait rien côté serveur)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = {}

Icons.Prefix = "ICON_"
Icons.Folder = { "Assets", "Icons" }

function Icons.name(itemId: string): string
	return Icons.Prefix .. itemId
end

local function isIcon(inst: Instance?, name: string): boolean
	return inst ~= nil and inst.Name == name and inst:IsA("Decal") and (inst :: Decal).Texture ~= ""
end

-- Premier Decal `name` à Texture non vide parmi les descendants de `root`.
local function firstDecal(root: Instance, name: string): Decal?
	for _, descendant in root:GetDescendants() do
		if isIcon(descendant, name) then
			return descendant :: Decal
		end
	end
	return nil
end

function Icons.find(itemId: string): Decal?
	local assets = ReplicatedStorage:FindFirstChild(Icons.Folder[1])
	if assets == nil then
		return nil
	end
	local name = Icons.name(itemId)
	local folder: Instance? = assets
	for index = 2, #Icons.Folder do
		folder = if folder then folder:FindFirstChild(Icons.Folder[index]) else nil
	end
	if folder ~= nil then
		-- Le cas courant : rangée directement dans Assets/Icons (une recherche, sans parcours).
		local direct = folder:FindFirstChild(name)
		if isIcon(direct, name) then
			return direct :: Decal
		end
		local nested = firstDecal(folder, name)
		if nested ~= nil then
			return nested
		end
	end
	return firstDecal(assets, name)
end

function Icons.get(itemId: string): string?
	local decal = Icons.find(itemId)
	return if decal then decal.Texture else nil
end

function Icons.preload(textures: { string })
	if #textures == 0 or not RunService:IsClient() then
		return
	end
	-- Pris ici et pas en tête du module : seul le client en a besoin, et seulement s'il y a des
	-- icônes à montrer.
	local ContentProvider = game:GetService("ContentProvider")
	pcall(function()
		ContentProvider:PreloadAsync(textures)
	end)
end

return Icons

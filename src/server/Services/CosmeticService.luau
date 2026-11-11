--!strict
-- CosmeticService (DEV-032) : auras et trails possédés, équipés, multiplicateurs et effets
-- (Partie 1, sections 5.10, 7.1 et 7.4 ; remote EquipCosmetic 9.4 ; sauvegarde 9.5 :
-- Cosmetics.Auras, Cosmetics.Trails, Cosmetics.EquippedAura et Cosmetics.EquippedTrail).
--
-- Rôle :
--   - possession : on garde tout ce qu'on a acheté (5.10). L'achat lui-même (prix, argent) est
--     fait par ShopService (BuyItem), qui appelle Grant une fois l'achat payé ;
--   - équipement : une aura et un trail à la fois. Le remote EquipCosmetic(cosmeticId) équipe une
--     aura ou un trail possédé, à la place de celui du même type ; le renvoyer pour l'objet déjà
--     équipé l'enlève. C'est enregistré dans le profil ;
--   - multiplicateurs (7.1) : remplace les points d'accroche ToolService.GetAuraMultiplier
--     (dégâts = puissance × (1 + Force / 100) × M aura) et StatsService.GetTrailMultiplier
--     (WalkSpeed = min(70, 16 + 0,05 × Vitesse × M trail)), puis appelle ToolService.RefreshDamage
--     et StatsService.Refresh au chargement du profil et à chaque changement : l'attribut Damage
--     du HUD et la WalkSpeed suivent ;
--   - effets visibles par tous (5.10), créés ici sur le personnage à chaque apparition, retirés à
--     la mort :
--       aura  : pièce invisible CosmeticAura soudée au HumanoidRootPart, autour du corps, avec des
--               particules et une lumière, plus fournies à chaque palier (étincelles en plus à
--               partir du palier 3) ;
--       trail : Trail CosmeticTrail entre deux Attachments du HumanoidRootPart, dans le dos
--               (CosmeticTrailTop et CosmeticTrailBottom) : il se voit surtout en courant.
--     Texture : celle de Clément (MOD-045), le Decal nommé comme le champ Texture de
--     Config/Cosmetics, cherché dans ReplicatedStorage/Assets, sous-dossiers compris. Tant qu'il
--     manque : V0, texture d'étincelles livrée avec Roblox (aura) ou ruban uni (trail). La couleur
--     du palier (Config/Cosmetics, Color) teinte particules, lumière et trail.
--     Objets natifs seulement (Part, WeldConstraint, Attachment, ParticleEmitter, PointLight,
--     Trail), aucun script dans le personnage.
--   - effets complets de Clément (vague 26, L-097 point 1), prioritaires sur ceux ci-dessus : le
--     modèle FX_Aura_<Nom> ou FX_Trail_<Nom> (même nom que le champ Texture de Config/Cosmetics,
--     cherché dans ReplicatedStorage/Assets, sous-dossiers compris : Assets/FX/Auras, Assets/FX/Trails)
--     reprend les pièces R15 (UpperTorso, Head, mains, pieds, HumanoidRootPart). Chaque Attachment
--     d'une pièce du modèle est copié, avec ses émetteurs, lumières, Beams et Trails, sur la pièce de
--     même nom du personnage (même CFrame relatif). Un Beam ou un Trail qui relie deux Attachments du
--     modèle est relié aux copies ; s'il vise une pièce que le personnage n'a pas, il est retiré.
--     Chaque copie porte l'attribut CosmeticFx (« Aura » ou « Trail ») et CosmeticId ; une copie
--     d'aura porte aussi le tag CosmeticAura, et ses ParticleEmitter l'attribut FullRate (comme la
--     pièce V0). Retirées au changement et à la mort ; le personnage part avec le joueur. Sans modèle
--     (ou sans aucune pièce commune avec le personnage) : l'effet V0 ci-dessus.
-- Le serveur décide tout. Un refus qu'un joueur honnête peut rencontrer (objet pas possédé,
-- sauvegarde pas encore chargée) reçoit un Notify en anglais (L-036) ; un Id inconnu, impossible
-- depuis l'UI, n'est écrit que dans la sortie, en Studio.
--
-- API (serveur) :
--   CosmeticService.Owns(player, cosmeticId) -> boolean
--       true si le profil est chargé et que l'aura ou le trail est possédé.
--   CosmeticService.Grant(player, cosmeticId) -> boolean
--       Ajoute l'aura ou le trail aux possédés, sans l'équiper. true aussi s'il était déjà
--       possédé ; false si le profil n'est pas chargé ou si l'Id est inconnu de Config/Cosmetics.
--       Ne touche pas à l'argent : ShopService vérifie le prix et Owns, appelle
--       DataService.SpendCash, puis Grant.
--   CosmeticService.Equip(player, cosmeticId) -> boolean
--       Équipe un objet possédé à la place de celui du même type (rien ne change s'il l'est déjà).
--       false si le profil n'est pas chargé, l'Id inconnu ou l'objet pas possédé.
--   CosmeticService.Unequip(player, kind) -> boolean
--       Retire l'aura (kind = "Aura") ou le trail (kind = "Trail") équipé.
--   CosmeticService.GetEquippedId(player, kind) -> string?
--       Objet équipé de ce type ; un Id enregistré inconnu ou pas possédé compte comme rien.
--   CosmeticService.GetAuraMultiplier(player) -> number     M aura, 1 sans aura (7.1)
--   CosmeticService.GetTrailMultiplier(player) -> number    M trail, 1 sans trail (7.1)
--
-- Attributs du Player (écrits seulement ici, lus par AuraShopController) :
--   OwnedCosmetics   Id possédés connus de Config/Cosmetics, séparés par des virgules (« Spark,Dust »)
--   EquippedAura     Id de l'aura équipée ; absent sans aura
--   EquippedTrail    Id du trail équipé ; absent sans trail
-- Lu par CosmeticController (client) : les copies des modèles FX_ portent l'attribut CosmeticFx ;
-- la pièce CosmeticAura et chaque Attachment copié d'une aura portent le tag de code « CosmeticAura »
-- (pas un tag de la map) et chacun de ses ParticleEmitter l'attribut FullRate (débit plein).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)
local ToolService = require(script.Parent.ToolService)

type Data = ProfileTypes.Data
type Cosmetic = Cosmetics.Cosmetic
type Kind = Cosmetics.CosmeticKind

-- Effets dans le personnage. AURA_TAG et FULL_RATE_ATTRIBUTE : mêmes noms dans CosmeticController.
local AURA_PART = "CosmeticAura"
local AURA_TAG = "CosmeticAura" -- tag de code, pas un tag de la map
local FULL_RATE_ATTRIBUTE = "FullRate"
local TRAIL_NAME = "CosmeticTrail"
local TRAIL_TOP = "CosmeticTrailTop"
local TRAIL_BOTTOM = "CosmeticTrailBottom"
local COSMETIC_ID_ATTRIBUTE = "CosmeticId" -- Id de Config/Cosmetics, sur la pièce d'aura et le Trail
-- Sur chaque Attachment copié d'un modèle FX_ de Clément : "Aura" ou "Trail". Même nom dans CosmeticController.
local FX_ATTRIBUTE = "CosmeticFx"
local ROOT_PART = "HumanoidRootPart"
-- Dossier des assets de Clément (9.2), où l'on cherche ses textures.
local ASSETS_FOLDER = "Assets"

-- Attributs du Player : mêmes noms dans AuraShopController.
local OWNED_ATTRIBUTE = "OwnedCosmetics"
local AURA_ATTRIBUTE = "EquippedAura"
local TRAIL_ATTRIBUTE = "EquippedTrail"

-- V0 proposé, absent du doc : volume de l'aura autour d'un perso R15 d'environ 5 studs (10.1),
-- centré un peu sous le HumanoidRootPart (les pieds sont 3 studs plus bas, la tête 2 plus haut).
local AURA_SIZE = Vector3.new(3.5, 5.5, 3.5)
local AURA_OFFSET = CFrame.new(0, -0.5, 0)
-- V0 proposé, absent du doc : texture des particules tant que celle de Clément manque (fichier
-- livré avec Roblox, comme pour le halo de CarryService).
local V0_PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type AuraSpec = {
	Rate: number, -- particules par seconde (débit plein)
	Size: number, -- taille de départ d'une particule (studs)
	Rise: number, -- montée des particules (studs/s²)
	Light: number, -- Brightness de la lumière
	Range: number, -- portée de la lumière (studs)
	Sparks: number, -- étincelles par seconde ; 0 = aucune
}

-- V0 proposé, absent du doc : « plus spectaculaire à chaque palier » (5.10), par Order (1 à 6).
-- Un palier ajouté à Config prend le dernier réglage.
local AURA_SPECS: { AuraSpec } = {
	{ Rate = 8, Size = 0.35, Rise = 1.5, Light = 0.8, Range = 6, Sparks = 0 }, -- Spark
	{ Rate = 12, Size = 0.45, Rise = 2, Light = 1.2, Range = 8, Sparks = 0 }, -- Flame
	{ Rate = 16, Size = 0.5, Rise = 2.5, Light = 1.6, Range = 10, Sparks = 5 }, -- Lightning
	{ Rate = 20, Size = 0.55, Rise = 3, Light = 2, Range = 12, Sparks = 8 }, -- Plasma
	{ Rate = 26, Size = 0.6, Rise = 3.5, Light = 2.5, Range = 14, Sparks = 12 }, -- Galaxy
	{ Rate = 32, Size = 0.7, Rise = 4, Light = 3, Range = 16, Sparks = 18 }, -- Royal
}

type TrailSpec = {
	Height: number, -- écart entre les deux Attachments (studs)
	Lifetime: number, -- durée de vie du ruban (s)
	Glow: number, -- LightEmission
}

-- V0 proposé, absent du doc : ruban plus haut, plus long et plus lumineux à chaque palier, par
-- Order (1 à 5). Un palier ajouté à Config prend le dernier réglage.
local TRAIL_SPECS: { TrailSpec } = {
	{ Height = 1.6, Lifetime = 0.3, Glow = 0.2 }, -- Dust
	{ Height = 1.9, Lifetime = 0.4, Glow = 0.4 }, -- Wind
	{ Height = 2.2, Lifetime = 0.5, Glow = 0.6 }, -- Turbo
	{ Height = 2.5, Lifetime = 0.6, Glow = 0.8 }, -- Comet
	{ Height = 2.8, Lifetime = 0.75, Glow = 1 }, -- Hyperspace
}
-- V0 : milieu du ruban, dans le repère du HumanoidRootPart (le perso regarde −Z, son dos est en +Z).
local TRAIL_CENTER = Vector3.new(0, -0.2, 0.6)

-- V0 proposé, absent du doc : attente max (s) du HumanoidRootPart d'un perso qui apparaît.
local ROOT_WAIT = 10

-- Refus honnêtes, lus par le joueur : en anglais (L-036).
local MESSAGES = {
	NotLoaded = "Your save is still loading. Try again in a moment.",
}

local function notOwnedMessage(def: Cosmetic): string
	local word = if def.Kind == "Aura" then "aura" else "trail"
	return `You don't own the {def.DisplayName} {word} yet: buy it first.`
end

local IS_STUDIO = RunService:IsStudio()

local CosmeticService = {}

local watched: { [Player]: boolean } = {}
local reported: { [string]: boolean } = {}

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

local function notify(player: Player, message: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, "Warning")
	end)
	if not ok then
		warn(`[CosmeticService] Notify vers {player.Name} : {err}`)
	end
end

-- Profil ------------------------------------------------------------------------------------

local function ownedList(data: Data, kind: Kind): { string }
	return if kind == "Aura" then data.Cosmetics.Auras else data.Cosmetics.Trails
end

local function ownsDef(data: Data, def: Cosmetic): boolean
	return table.find(ownedList(data, def.Kind), def.Id) ~= nil
end

local function savedEquippedId(data: Data, kind: Kind): string?
	return if kind == "Aura" then data.Cosmetics.EquippedAura else data.Cosmetics.EquippedTrail
end

local function setEquippedId(data: Data, kind: Kind, id: string?)
	if kind == "Aura" then
		data.Cosmetics.EquippedAura = id
	else
		data.Cosmetics.EquippedTrail = id
	end
end

-- Objet équipé de ce type s'il est connu, du bon type et possédé ; sinon nil. Un Id inconnu
-- (aura d'une version plus récente du jeu) reste enregistré : on ne retire jamais un achat.
local function equippedDef(data: Data, kind: Kind): Cosmetic?
	local id = savedEquippedId(data, kind)
	local def: Cosmetic? = if type(id) == "string" then Cosmetics.ById[id] else nil
	if def ~= nil and def.Kind == kind and ownsDef(data, def) then
		return def
	end
	return nil
end

local function writeAttributes(player: Player, data: Data)
	local owned: { string } = {}
	local function collect(kind: Kind)
		for _, id in ownedList(data, kind) do
			local def: Cosmetic? = Cosmetics.ById[id]
			if def ~= nil and def.Kind == kind and table.find(owned, id) == nil then
				table.insert(owned, id)
			end
		end
	end
	collect("Aura")
	collect("Trail")
	player:SetAttribute(OWNED_ATTRIBUTE, table.concat(owned, ","))
	local aura = equippedDef(data, "Aura")
	local trail = equippedDef(data, "Trail")
	player:SetAttribute(AURA_ATTRIBUTE, if aura then aura.Id else nil)
	player:SetAttribute(TRAIL_ATTRIBUTE, if trail then trail.Id else nil)
end

-- Effets -------------------------------------------------------------------------------------

-- Texture du premier Decal de Clément nommé `name` (ReplicatedStorage/Assets, sous-dossiers
-- compris), ou nil s'il n'est pas livré. On cherche un Decal, pas le premier objet de ce nom : les
-- modèles d'effet de Clément portent les mêmes noms (Assets/FX/Auras, Assets/FX/Trails, L-042).
local function clementTexture(name: string): string?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	for _, found in if assets then Find.all(assets, name) else {} do
		if found:IsA("Decal") and (found :: Decal).Texture ~= "" then
			return (found :: Decal).Texture
		end
	end
	reportOnce(name, `[CosmeticService] texture {name} pas encore livrée dans ReplicatedStorage/Assets (MOD-045) : effet V0`)
	return nil
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild(ROOT_PART)
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health > 0
end

-- Copies des modèles FX_ de Clément de ce type, sur toutes les pièces du personnage.
local function clearFx(character: Model, kind: Kind)
	for _, inst in character:GetDescendants() do
		if inst:IsA("Attachment") and inst:GetAttribute(FX_ATTRIBUTE) == kind then
			inst:Destroy()
		end
	end
end

local function clearAura(character: Model)
	for _, child in character:GetChildren() do
		if child.Name == AURA_PART and child:IsA("BasePart") then
			child:Destroy()
		end
	end
	clearFx(character, "Aura")
end

local function clearTrail(character: Model)
	local root = rootOf(character)
	if root then
		for _, child in root:GetChildren() do
			local name = child.Name
			if name == TRAIL_NAME or name == TRAIL_TOP or name == TRAIL_BOTTOM then
				child:Destroy()
			end
		end
	end
	clearFx(character, "Trail")
end

-- Modèle d'effet complet de Clément (FX_Aura_<Nom> / FX_Trail_<Nom>, même nom que le champ
-- Texture), ou nil s'il n'est pas livré. Le Decal homonyme est ignoré.
local fxModels: { [string]: Model } = {} -- modèles déjà trouvés (Assets est grand : une recherche par nom)
local function clementFxModel(name: string): Model?
	local cached = fxModels[name]
	if cached and cached.Parent ~= nil then
		return cached
	end
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	local candidates: { Instance } = if assets then Find.all(assets, name) else {}
	for _, found in candidates do
		if found:IsA("Model") then
			fxModels[name] = found :: Model
			return found :: Model
		end
	end
	reportOnce(`model:{name}`, `[CosmeticService] modèle {name} pas livré dans ReplicatedStorage/Assets (L-097) : effet par texture`)
	return nil
end

type Placed = { copy: Attachment, target: BasePart }

-- Copie sur `character` les Attachments de chaque pièce du modèle `model` (pièce de même nom).
-- false si aucune pièce du modèle n'existe dans le personnage (rien n'est posé).
local function attachFx(def: Cosmetic, character: Model, model: Model): boolean
	local copies: { [Instance]: Attachment } = {} -- [Attachment du modèle] = copie
	local isCopy: { [Instance]: boolean } = {}
	local placed: { Placed } = {}
	for _, source in model:GetChildren() do
		if not source:IsA("BasePart") then
			continue
		end
		local target = character:FindFirstChild(source.Name)
		if target == nil or not target:IsA("BasePart") then
			reportOnce(`part:{model.Name}:{source.Name}`, `[CosmeticService] {model.Name} : pas de pièce {source.Name} dans le personnage, ses effets sont ignorés`)
			continue
		end
		for _, child in source:GetChildren() do
			if child:IsA("Attachment") then
				local copy = child:Clone() :: Attachment
				copy:SetAttribute(FX_ATTRIBUTE, def.Kind)
				copy:SetAttribute(COSMETIC_ID_ATTRIBUTE, def.Id)
				copies[child] = copy
				isCopy[copy] = true
				table.insert(placed, { copy = copy, target = target :: BasePart })
			end
		end
	end
	if #placed == 0 then
		return false
	end
	-- Beams et Trails reliés aux copies (un lien interne à une copie l'est déjà par Clone). Un lien
	-- vers un Attachment qui n'est ni copié ni une copie (pièce absente du personnage) : effet retiré.
	local function relink(attachment: Attachment?): (Attachment?, boolean)
		if attachment == nil then
			return nil, true
		end
		local copy = copies[attachment]
		if copy then
			return copy, true
		end
		return attachment, isCopy[attachment] == true
	end
	for _, entry in placed do
		for _, inst in entry.copy:GetDescendants() do
			if inst:IsA("Beam") or inst:IsA("Trail") then
				local effect = inst :: any
				local a0, ok0 = relink(effect.Attachment0)
				local a1, ok1 = relink(effect.Attachment1)
				if ok0 and ok1 then
					effect.Attachment0 = a0
					effect.Attachment1 = a1
				else
					inst:Destroy()
				end
			elseif def.Kind == "Aura" and inst:IsA("ParticleEmitter") then
				inst:SetAttribute(FULL_RATE_ATTRIBUTE, (inst :: ParticleEmitter).Rate)
			end
		end
		if def.Kind == "Aura" then
			CollectionService:AddTag(entry.copy, AURA_TAG)
		end
	end
	for _, entry in placed do
		entry.copy.Parent = entry.target
	end
	return true
end

-- Pose l'effet complet de Clément si son modèle est livré ; false sinon (l'appelant pose l'effet V0).
local function tryClementFx(def: Cosmetic, character: Model): boolean
	local model = clementFxModel(def.Texture)
	return model ~= nil and attachFx(def, character, model)
end

local function newEmitter(name: string, texture: string, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Rate = rate
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter:SetAttribute(FULL_RATE_ATTRIBUTE, rate)
	return emitter
end

-- Pièce d'aura de `def`, soudée à `root`, pas encore parentée.
local function buildAura(def: Cosmetic, root: BasePart): BasePart
	local spec = AURA_SPECS[math.clamp(def.Order, 1, #AURA_SPECS)]
	local texture = clementTexture(def.Texture) or V0_PARTICLE_TEXTURE

	local part = Instance.new("Part")
	part.Name = AURA_PART
	part.Size = AURA_SIZE
	part.CFrame = root.CFrame * AURA_OFFSET
	part.Transparency = 1
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false -- ne déclenche aucun contact (tapis de caisse…)
	part.CastShadow = false
	part.Massless = true
	part:SetAttribute(COSMETIC_ID_ATTRIBUTE, def.Id)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = def.Color
	light.Brightness = spec.Light
	light.Range = spec.Range
	light.Shadows = false
	light.Parent = part

	local particles = newEmitter("AuraParticles", texture, spec.Rate)
	particles.Color = ColorSequence.new(def.Color)
	particles.Lifetime = NumberRange.new(0.8, 1.4)
	particles.Speed = NumberRange.new(0.2, 0.6)
	particles.Acceleration = Vector3.new(0, spec.Rise, 0)
	particles.Size = NumberSequence.new(spec.Size, 0)
	particles.Transparency = NumberSequence.new(0.15, 1)
	particles.LockedToPart = true -- l'aura suit le perso au lieu de traîner derrière lui
	particles.Parent = part

	if spec.Sparks > 0 then
		local sparks = newEmitter("AuraSparks", texture, spec.Sparks)
		sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), def.Color)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(2, 4)
		sparks.Size = NumberSequence.new(spec.Size * 0.6, 0)
		sparks.Transparency = NumberSequence.new(0, 1)
		sparks.Parent = part
	end

	CollectionService:AddTag(part, AURA_TAG)
	return part
end

-- Trail de `def` entre deux Attachments de `root`.
local function buildTrail(def: Cosmetic, root: BasePart)
	local spec = TRAIL_SPECS[math.clamp(def.Order, 1, #TRAIL_SPECS)]
	local texture = clementTexture(def.Texture)
	local half = Vector3.new(0, spec.Height / 2, 0)

	local top = Instance.new("Attachment")
	top.Name = TRAIL_TOP
	top.Position = TRAIL_CENTER + half
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_BOTTOM
	bottom.Position = TRAIL_CENTER - half

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(def.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Lifetime = spec.Lifetime
	trail.LightEmission = spec.Glow
	trail.LightInfluence = 0
	trail.FaceCamera = false
	if texture then
		trail.Texture = texture
	end
	trail:SetAttribute(COSMETIC_ID_ATTRIBUTE, def.Id)

	top.Parent = root
	bottom.Parent = root
	trail.Parent = root
end

-- (Re)crée sur le personnage l'effet de `kind` ("Aura" ou "Trail"), ou des deux sans `kind`.
local function applyEffects(player: Player, kind: Kind?)
	local character = player.Character
	local data = DataService.Get(player)
	if character == nil or data == nil or not isAlive(character) then
		return
	end
	local root = rootOf(character)
	if root == nil then
		return
	end
	if kind ~= "Trail" then
		clearAura(character)
		local def = equippedDef(data, "Aura")
		if def and not tryClementFx(def, character) then
			buildAura(def, root).Parent = character
		end
	end
	if kind ~= "Aura" then
		clearTrail(character)
		local def = equippedDef(data, "Trail")
		if def and not tryClementFx(def, character) then
			buildTrail(def, root)
		end
	end
end

local function clearEffects(character: Model)
	clearAura(character)
	clearTrail(character)
end

local function onCharacter(player: Player, character: Model)
	local root = character:FindFirstChild(ROOT_PART) or character:WaitForChild(ROOT_PART, ROOT_WAIT)
	if player.Character ~= character or not watched[player] then
		return
	end
	if root == nil then
		reportOnce(ROOT_PART, `[CosmeticService] {player.Name} : pas de {ROOT_PART} dans le personnage, aura et trail non posés`)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Sans soudure à la mort, l'aura tomberait dans le vide en brillant jusqu'à la réapparition.
		humanoid.Died:Connect(function()
			clearEffects(character)
		end)
	end
	applyEffects(player)
end

local function watchPlayer(player: Player)
	if watched[player] then
		return
	end
	watched[player] = true
	player.CharacterAdded:Connect(function(character: Model)
		onCharacter(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacter, player, character)
	end
end

-- Après un équipement ou un retrait : attributs, effet et multiplicateurs.
local function onChanged(player: Player, data: Data, kind: Kind)
	writeAttributes(player, data)
	applyEffects(player, kind)
	ToolService.RefreshDamage(player)
	StatsService.Refresh(player)
	if IS_STUDIO then
		local def = equippedDef(data, kind)
		local word = if kind == "Aura" then "aura" else "trail"
		print(
			if def
				then `[CosmeticService] {player.Name} : {word} {def.Id} équipé(e), ×{def.Multiplier}`
				else `[CosmeticService] {player.Name} : {word} retiré(e)`
		)
	end
end

-- API ----------------------------------------------------------------------------------------

function CosmeticService.Owns(player: Player, cosmeticId: string): boolean
	local data = DataService.Get(player)
	local def: Cosmetic? = Cosmetics.ById[cosmeticId]
	return data ~= nil and def ~= nil and ownsDef(data, def)
end

function CosmeticService.Grant(player: Player, cosmeticId: string): boolean
	local data = DataService.Get(player)
	local def: Cosmetic? = Cosmetics.ById[cosmeticId]
	if data == nil or def == nil then
		return false
	end
	if not ownsDef(data, def) then
		table.insert(ownedList(data, def.Kind), def.Id)
		writeAttributes(player, data)
	end
	return true
end

function CosmeticService.Equip(player: Player, cosmeticId: string): boolean
	local data = DataService.Get(player)
	local def: Cosmetic? = Cosmetics.ById[cosmeticId]
	if data == nil or def == nil or not ownsDef(data, def) then
		return false
	end
	if equippedDef(data, def.Kind) ~= def then
		setEquippedId(data, def.Kind, def.Id)
		onChanged(player, data, def.Kind)
	end
	return true
end

function CosmeticService.Unequip(player: Player, kind: Kind): boolean
	local data = DataService.Get(player)
	if data == nil or (kind ~= "Aura" and kind ~= "Trail") then
		return false
	end
	if savedEquippedId(data, kind) ~= nil then
		setEquippedId(data, kind, nil)
		onChanged(player, data, kind)
	end
	return true
end

function CosmeticService.GetEquippedId(player: Player, kind: Kind): string?
	local data = DataService.Get(player)
	local def = if data then equippedDef(data, kind) else nil
	return if def then def.Id else nil
end

function CosmeticService.GetAuraMultiplier(player: Player): number
	local data = DataService.Get(player)
	local def = if data then equippedDef(data, "Aura") else nil
	return if def then def.Multiplier else Cosmetics.NoneMultiplier
end

function CosmeticService.GetTrailMultiplier(player: Player): number
	local data = DataService.Get(player)
	local def = if data then equippedDef(data, "Trail") else nil
	return if def then def.Multiplier else Cosmetics.NoneMultiplier
end

-- Remote EquipCosmetic(cosmeticId) : forme déjà contrôlée par Net (chaîne de 1 à 64 caractères,
-- 4 appels par seconde au plus).
local function onEquipCosmetic(player: Player, cosmeticId: string)
	local def: Cosmetic? = Cosmetics.ById[cosmeticId]
	if def == nil then
		if IS_STUDIO then
			warn(`[CosmeticService] {player.Name} : EquipCosmetic « {cosmeticId} » inconnu de Config/Cosmetics, ignoré`)
		end
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		notify(player, MESSAGES.NotLoaded)
		return
	end
	if not ownsDef(data, def) then
		notify(player, notOwnedMessage(def))
		return
	end
	if equippedDef(data, def.Kind) == def then
		CosmeticService.Unequip(player, def.Kind)
	else
		CosmeticService.Equip(player, def.Id)
	end
end

function CosmeticService.Init()
	-- Points d'accroche de ToolService et StatsService (voir leurs en-têtes).
	ToolService.GetAuraMultiplier = CosmeticService.GetAuraMultiplier
	StatsService.GetTrailMultiplier = CosmeticService.GetTrailMultiplier

	Net.Server.EquipCosmetic:Connect(onEquipCosmetic)
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		watched[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	DataService.OnProfileLoaded(function(player: Player)
		local data = DataService.Get(player)
		if data == nil then
			return
		end
		writeAttributes(player, data)
		applyEffects(player)
		ToolService.RefreshDamage(player)
		StatsService.Refresh(player)
		local aura, trail = equippedDef(data, "Aura"), equippedDef(data, "Trail")
		if IS_STUDIO and (aura or trail) then
			print(`[CosmeticService] {player.Name} : aura {if aura then aura.Id else "aucune"}, trail {if trail then trail.Id else "aucun"}`)
		end
	end)
end

return CosmeticService

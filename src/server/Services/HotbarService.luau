--!strict
-- HotbarService (vague 25, retour du Play de Cantin du 2026-11-11) : la disposition de la barre du bas
-- UI_Hotbar choisie par le joueur, gardée d'une session à l'autre (Shared/HotbarLayout, HotbarController).
--
-- Rôle :
--   - chargement du profil : le champ facultatif Hotbar (sans changement de version ; absent = rien de
--     sauvegardé) est nettoyé (un uid qui n'est plus ni dans Items ni dans Boxes du profil devient une
--     case vide, un identifiant en double ou mal formé aussi) et posé dans l'attribut HotbarLayout du
--     Player (texte de HotbarLayout.Encode ; texte vide = rien de sauvegardé : le client fait la
--     disposition de départ). Le profil nettoyé est gardé ;
--   - SetHotbar(slot1 … slot6) : Net a déjà contrôlé la forme (6 textes de 64 caractères au plus, 7e
--     argument refusé) et le débit. Le service refuse toute la disposition si un identifiant n'est ni
--     "Tool", ni "Bat", ni vide, ni l'uid d'un colis ou d'un objet de CE joueur (Items ou Boxes du
--     profil : un objet exposé ou un colis posé est encore à lui), ou s'il est en double : rien ne change
--     (une ligne en Studio). Acceptée : champ Hotbar remplacé, attribut remis.
-- Rien de sensible : la disposition ne donne rien ; chaque action d'une case repasse par son propre remote.
--
-- API (côté serveur) :
--   HotbarService.Get(player) -> { string }?   disposition sauvegardée (nil : rien, ou profil pas chargé)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local HotbarLayout = require(Shared.HotbarLayout)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data

local IS_STUDIO = RunService:IsStudio()

local HotbarService = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[HotbarService] {message}`)
	end
end

-- L'identifiant est-il à ce joueur ? "Tool" et "Bat" : toujours (ToolService les donne à tous).
local function owns(data: Data, id: string): boolean
	if id == HotbarLayout.Tool or id == HotbarLayout.Bat then
		return true
	end
	return data.Items[id] ~= nil or data.Boxes[id] ~= nil
end

local function publish(player: Player, layout: { string }?)
	player:SetAttribute(HotbarLayout.Attribute, if layout then HotbarLayout.Encode(layout) else "")
end

function HotbarService.Get(player: Player): { string }?
	local data = DataService.Get(player)
	local saved = if data then data.Hotbar else nil
	if saved == nil then
		return nil
	end
	return table.clone(saved)
end

local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil or player.Parent == nil then
		return
	end
	local saved: { string }? = nil
	local stored: any = data.Hotbar
	if type(stored) == "table" then
		-- HotbarLayout.Decode(HotbarLayout.Encode(…)) : Size cases, valides et sans double.
		local layout = HotbarLayout.Decode(HotbarLayout.Encode(stored)) or HotbarLayout.Default()
		for index, id in layout do
			if id ~= HotbarLayout.Empty and not owns(data, id) then
				layout[index] = HotbarLayout.Empty -- parti (vendu, ouvert, volé) : case vide
			end
		end
		saved = layout
		data.Hotbar = layout
	elseif stored ~= nil then
		data.Hotbar = nil -- champ abîmé : comme rien de sauvegardé
	end
	publish(player, saved)
end

local function onSet(player: Player, ...: string?)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local layout: { string } = {}
	local seen: { [string]: boolean } = {}
	for index = 1, HotbarLayout.Size do
		local value: string? = select(index, ...)
		local id: string = value or HotbarLayout.Empty
		if id ~= HotbarLayout.Empty then
			if not HotbarLayout.IsId(id) or not owns(data, id) then
				log(`{player.Name} : case {index} « {id} » pas à lui, disposition refusée`)
				return
			end
			if seen[id] then
				log(`{player.Name} : « {id} » en double, disposition refusée`)
				return
			end
			seen[id] = true
		end
		table.insert(layout, id)
	end
	data.Hotbar = layout
	publish(player, layout)
end

function HotbarService.Init()
	Net.Server.SetHotbar:Connect(onSet)
	DataService.OnProfileLoaded(onProfileLoaded)
end

return HotbarService

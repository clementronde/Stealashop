--!strict
-- DropService (vague 33, Cantin 2026-11-13, agent a113) : le joueur lâche lui-même ce qu'il porte au-dessus
-- de la tête (objet sorti d'un colis NPCItem, objet volé PlayerItem, ancien colis NPCBox).
--
-- Remote DropCarried (Net/Definitions, aucun argument, 2 par seconde au plus), envoyé par DropController
-- (touche G sur PC, bouton « Drop » sur téléphone). Vérifié ici dans cet ordre, refus sans rien changer :
--   1. personnage vivant (Humanoid avec des PV, HumanoidRootPart, dans Workspace) ;
--   2. il porte quelque chose (CarryService.IsCarrying) ;
--   3. pas étourdi : ni par une capture (GuardService.IsStunned : vigile, police, conducteur, nuit), ni par
--      un coup de batte (BatService.IsStunned) ;
--   4. au plus un lâcher toutes les DROP_COOLDOWN s (en plus du débit de Net) ;
--   5. déplacements contrôlés par l'anti-triche (AntiCheatService.Verify) : un téléport juste avant ne pose
--      pas l'objet loin de son vrai chemin.
-- Puis CarryService.Drop(player, nil, "Released") : la mécanique du coup de batte, sans coup ni étourdissement.
--   - colis PNJ et objet NPCItem : au sol sous le joueur (Workspace/CarryDrops, attribut BatDrop), reprenable
--     par n'importe qui avec GrabDropped (BatService, mêmes règles, le joueur qui l'a lâché compris), et
--     revole vers son rayon au bout de Bat.DroppedLifetime s sans preneur (StoreHeistService) ;
--   - objet volé à un joueur : comme après un coup de batte, il ne tombe pas, il revole tout de suite vers
--     le présentoir de son propriétaire (PvPService, OnCarryEnded « Failed », raison « Released ») ;
--   - vigile : comme après une chute à la batte (GuardService écoute OnCarryEnded « Dropped », quelle que
--     soit la raison) : il quitte le joueur, va vers l'objet au sol, poursuit celui qui le ramasse, abandonne
--     si personne ne le ramasse.
--
-- API (serveur) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net.Net)

local AntiCheatService = require(script.Parent.AntiCheatService)
local BatService = require(script.Parent.BatService)
local CarryService = require(script.Parent.CarryService)
local GuardService = require(script.Parent.GuardService)

-- Raison passée à OnCarryEnded (CarryService.Drop) : le joueur a lâché lui-même.
local RELEASE_REASON = "Released"
-- V0 proposé, absent du doc : au plus un lâcher accepté toutes les 0,5 s par joueur.
local DROP_COOLDOWN = 0.5

local IS_STUDIO = RunService:IsStudio()

local DropService = {}

local lastDropAt: { [Player]: number } = {}

local function refuse(player: Player, message: string)
	if IS_STUDIO then
		warn(`[DropService] DropCarried de {player.Name} refusé : {message}`)
	end
end

local function aliveCharacter(player: Player): boolean
	local character = player.Character
	if character == nil or not character:IsDescendantOf(Workspace) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")
end

local function onDropCarried(player: Player)
	if not aliveCharacter(player) then
		refuse(player, "pas de personnage vivant")
		return
	end
	if not CarryService.IsCarrying(player) then
		refuse(player, "ne porte rien")
		return
	end
	if GuardService.IsStunned(player) then
		refuse(player, "étourdi par une capture")
		return
	end
	if BatService.IsStunned(player) then
		refuse(player, "étourdi par un coup de batte")
		return
	end
	local now = os.clock()
	if now - (lastDropAt[player] or -math.huge) < DROP_COOLDOWN then
		refuse(player, "trop rapproché")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	if not CarryService.IsCarrying(player) then
		return -- l'anti-triche vient de faire échouer le portage
	end
	lastDropAt[player] = now
	local dropId = CarryService.Drop(player, nil, RELEASE_REASON)
	if IS_STUDIO then
		print(`[DropService] {player.Name} lâche ce qu'il porte ({dropId or "rendu à son origine"})`)
	end
end

function DropService.Init()
	Net.Server.DropCarried:Connect(onDropCarried)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastDropAt[player] = nil
	end)
end

return DropService

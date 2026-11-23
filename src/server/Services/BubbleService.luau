--!strict
-- BubbleService (vague 64, a214) : les bulles ×N du tapis, côté serveur (décisions de Cantin du 2026-11-16 ; fiche
-- docs/claude/notes/2026-11-16_video-bulles-multiplicateur.md ; valeurs : Config/Bubbles).
--
-- Rôle (serveur autoritaire, rien de sensible ne vient du client) :
--   - pour chaque joueur en séance sur le tapis (TrainingService.IsTraining), une bulle toutes les Bubbles.SpawnMin à
--     SpawnMax s (au hasard), au plus Bubbles.MaxAtOnce à la fois ; une bulle due alors qu'il y en a déjà MaxAtOnce
--     est sautée. Sa valeur est tirée dans Bubbles.Chances. Le serveur garde son id, sa valeur et son heure de fin
--     (Bubbles.Lifetime) et l'envoie au seul joueur concerné (BubbleSpawn) ;
--   - ClaimBubble(id) : accepté seulement si la bulle est à ce joueur, pas expirée, pas déjà prise, s'il est toujours
--     sur le tapis et si son dernier ClaimBubble date d'au moins Bubbles.ClaimMinGap s (débit, en plus de Net). Gain =
--     TrainingService.GainPerSecond × N, versé par StatsService.AddSpeed (le chemin du tapis : stats et profil), une
--     seule fois. Le rythme du tapis ne change pas. Le client reçoit BubbleGone(id, "Claimed", gain), juste avant la
--     hausse de Speed (vague 65, a215 : il l'affiche alors « +X Speed », sans « /s ») ;
--   - bulle pas prise à temps : BubbleGone(id, "Expired") ; joueur descendu du tapis (ou parti) : toutes ses bulles
--     sont retirées (BubbleGone(id, "Cleared")), et le compte repart de zéro à la séance suivante.
--   Bubbles.Enabled = false : aucune bulle (celles en cours sont retirées).
--
-- API (côté serveur ; bancs) :
--   BubbleService.Draw(roll) -> number         multiplicateur pour un tirage roll dans [0, 100[ (Bubbles.Chances)
--   BubbleService.Claim(player, id) -> (boolean, string | number)
--                                                ce que fait ClaimBubble : (true, gain) ou (false, raison) ; raisons :
--                                                « NotTraining », « Rate », « Unknown » (pas à lui, déjà prise,
--                                                inconnue), « TooSoon » (a275 : apparue il y a moins de
--                                                Bubbles.ClaimMinAge s, elle reste à prendre), « Expired »
--   BubbleService.GetBubbles(player) -> { { id, multiplier, expiresAt } }   copie des bulles en cours
--   BubbleService.Step(now)                     un passage de la boucle (Heartbeat), pour les bancs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bubbles = require(ReplicatedStorage.Shared.Config.Bubbles)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local StatsService = require(script.Parent.StatsService)
local TrainingService = require(script.Parent.TrainingService)

export type Bubble = { id: string, multiplier: number, expiresAt: number }

type State = {
	bubbles: { Bubble },
	nextSpawnAt: number,
	lastClaimAt: number,
}

local BubbleService = {}

local states: { [Player]: State } = {}
local serial = 0
local rng = Random.new()

local function interval(): number
	return rng:NextNumber(Bubbles.SpawnMin, Bubbles.SpawnMax)
end

function BubbleService.Draw(roll: number): number
	local total = 0
	for _, chance in Bubbles.Chances do
		total += chance.Percent
		if roll < total then
			return chance.Multiplier
		end
	end
	return Bubbles.Chances[#Bubbles.Chances].Multiplier
end

local function spawnBubble(player: Player, state: State, now: number)
	serial += 1
	local bubble: Bubble = {
		id = `B{serial}`,
		multiplier = BubbleService.Draw(rng:NextNumber(0, 100)),
		expiresAt = now + Bubbles.Lifetime,
	}
	table.insert(state.bubbles, bubble)
	Net.Server.BubbleSpawn:Fire(player, bubble.id, bubble.multiplier, Bubbles.Lifetime)
end

-- Retire toutes les bulles du joueur (descendu du tapis, parti, bulles coupées).
local function clear(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	states[player] = nil
	if player.Parent == Players then
		for _, bubble in state.bubbles do
			Net.Server.BubbleGone:Fire(player, bubble.id, "Cleared")
		end
	end
end

local function stepPlayer(player: Player, now: number)
	if not (Bubbles.Enabled and TrainingService.IsTraining(player)) then
		clear(player)
		return
	end
	local state = states[player]
	if state == nil then
		-- Début de séance : la première bulle vient après un intervalle, comme les suivantes.
		state = { bubbles = {}, nextSpawnAt = now + interval(), lastClaimAt = -math.huge }
		states[player] = state
	end
	local current = state :: State
	for index = #current.bubbles, 1, -1 do
		local bubble = current.bubbles[index]
		if now >= bubble.expiresAt then
			table.remove(current.bubbles, index)
			Net.Server.BubbleGone:Fire(player, bubble.id, "Expired")
		end
	end
	if now >= current.nextSpawnAt then
		if #current.bubbles < Bubbles.MaxAtOnce then
			spawnBubble(player, current, now)
		end
		current.nextSpawnAt = now + interval()
	end
end

function BubbleService.Step(now: number)
	for _, player in Players:GetPlayers() do
		stepPlayer(player, now)
	end
	-- Joueurs partis entre deux passages (PlayerRemoving les retire aussi).
	for player in states do
		if player.Parent ~= Players then
			states[player] = nil
		end
	end
end

function BubbleService.Claim(player: Player, id: string): (boolean, string | number)
	local state = states[player]
	if state == nil or not TrainingService.IsTraining(player) then
		return false, "NotTraining"
	end
	local now = os.clock()
	if now - state.lastClaimAt < Bubbles.ClaimMinGap then
		return false, "Rate"
	end
	state.lastClaimAt = now
	local found: number? = nil
	for index, bubble in state.bubbles do
		if bubble.id == id then
			found = index
			break
		end
	end
	if found == nil then
		return false, "Unknown"
	end
	-- a275 (audit a272 F3) : bulle trop jeune pour un clic humain : refusée, elle reste à prendre.
	local fresh = state.bubbles[found] :: Bubble
	if now < fresh.expiresAt - Bubbles.Lifetime + Bubbles.ClaimMinAge then
		return false, "TooSoon"
	end
	local bubble = table.remove(state.bubbles, found) :: Bubble
	if now >= bubble.expiresAt then
		Net.Server.BubbleGone:Fire(player, bubble.id, "Expired")
		return false, "Expired"
	end
	local gain = TrainingService.GainPerSecond(player) * bubble.multiplier
	if not (gain == gain and gain > 0 and gain < math.huge) then
		gain = 0 -- gain invalide : rien de versé, la bulle est quand même prise
	end
	-- Vague 65 (a215) : annoncé AVANT la hausse de Speed (remotes et attributs arrivent dans l'ordre) : le client sait
	-- que cette hausse vient d'une bulle et l'affiche « +X Speed », sans « /s » (GainController.NoteBubble).
	Net.Server.BubbleGone:Fire(player, bubble.id, "Claimed", gain)
	if gain > 0 and StatsService.AddSpeed(player, gain) == nil then
		gain = 0 -- profil plus chargé : rien de versé (le client oublie l'annonce après Hud.BubbleGain.Window)
	end
	return true, gain
end

function BubbleService.GetBubbles(player: Player): { Bubble }
	local state = states[player]
	local copy: { Bubble } = {}
	if state then
		for _, bubble in state.bubbles do
			table.insert(copy, table.clone(bubble))
		end
	end
	return copy
end

function BubbleService.Init()
	Net.Server.ClaimBubble:Connect(function(player: Player, id: string)
		BubbleService.Claim(player, id)
	end)
	RunService.Heartbeat:Connect(function()
		BubbleService.Step(os.clock())
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

return BubbleService

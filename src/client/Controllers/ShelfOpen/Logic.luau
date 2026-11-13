--!strict
-- Logique pure de l'ouverture d'un colis sur son rayon (vague 31, liaison L-112), côté client : ce que
-- ShelfOpenController calcule sans toucher au monde, testable hors Studio (banc a104). Rangé dans un
-- sous-dossier : le Loader ne le démarre pas. Valeurs : Config/ShelfOpen et tableau d'animations de
-- Clément (T.53 à T.55, docs/claude/notes/ui-motion-skilltree.md) ; V0 = proposé, absent du doc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ShelfOpen = require(Config:WaitForChild("ShelfOpen"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Mutations = require(Config:WaitForChild("Mutations"))
local ShelfOpenState = require(Shared:WaitForChild("ShelfOpenState"))

local Logic = {}

-- T.53 : les rabats tournent de 115° autour de leur bord extérieur en 0,35 s (Back Out), puis la lumière :
-- InnerGlow de 0 à 3 en 0,25 s.
Logic.FlapAngle = math.rad(115)
Logic.FlapTime = 0.35
Logic.GlowTime = 0.25
Logic.GlowBase = 3
-- T.54 : le colis grandit de 1 à 1 + 0,6 × k, battement de + 4 % à chaque tic ; la lumière grandit avec k
-- (InnerLight.Width1 + 3, InnerGlow 3 → 7, Sparkles.Rate + 40) ; Row 1,12 → 1 en 0,1 s ; trèfle ± 10°.
Logic.Grow = 0.6
Logic.Beat = 0.04
Logic.LightWidthGain = 3
Logic.GlowGain = 4
Logic.SparkleGain = 40
Logic.RowPopFrom = 1.12
Logic.RowPopTime = 0.1
Logic.IconSwing = 10
Logic.BoardPopTime = 0.25 -- V0 : BB_ShelfOpen 0 → 1 à la fin des rabats (comme l'aperçu)
-- T.55 : l'objet sort 0,2 → 1 en 0,35 s (Back Out), blanc puis à ses couleurs en 0,2 s ; BB_Item 0 → 1 en
-- 0,3 s ; Flash 9 → 0 en 0,7 s ; Shaft effacé en 0,6 s après 0,55 s ; RevealTint 0,62 → 1 en 0,55 s.
Logic.ItemPopFrom = 0.2
Logic.ItemPopTime = 0.35
Logic.WhiteFadeTime = 0.2
Logic.ItemBoardPopTime = 0.3
Logic.FlashBrightness = 9
Logic.FlashTime = 0.7
Logic.ShaftDelay = 0.55
Logic.ShaftFadeTime = 0.6
Logic.TintFrom = 0.62
Logic.TintTime = 0.55
Logic.BoardHideTime = 0.15 -- aperçu : BB_ShelfOpen 1 → 0 en 0,15 s à la sortie
-- V0 proposé, absent du doc.
Logic.RevealWait = 2 -- s après ShelfRevealAt sans objet reçu : fin sans objet (rien n'est sorti chez nous)
Logic.RevealFxLife = 3 -- s de vie de FX_ShelfReveal (confettis 1,6 s, sons de sortie)
Logic.ConfettiDelay = 0.12 -- s entre Unbox_UpgradePop et Unbox_Confetti
Logic.ItemMatchDistance = 4 -- studs : un objet sorti sans SlotId est relié au colis le plus proche
Logic.ItemBoardLift = 1.6 -- aperçu : BB_Item à 1,6 stud au-dessus du haut de l'objet

-- Plus forte chance de la table (≥ 1) : le haut de l'échelle de croissance.
local maxLuck = 1
for _, entry in ShelfOpen.LuckTable do
	maxLuck = math.max(maxLuck, entry.Luck)
end
Logic.MaxLuck = maxLuck

-- Back Out (même courbe qu'Enum.EasingStyle.Back), de 0 à 1 avec un léger dépassement.
function Logic.backOut(t: number): number
	local x = math.clamp(t, 0, 1) - 1
	local c1 = 1.70158
	return 1 + (c1 + 1) * x * x * x + c1 * x * x
end

function Logic.quadOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

-- Texte de BB_ShelfOpen.Row.Luck : « ×1.25 LUCK ».
function Logic.luckText(luck: number): string
	return string.format("×%.2f LUCK", luck)
end

-- Fin de la montée : heure du serveur où la chance s'arrête (ShelfRevealAt, que le serveur peut avancer ;
-- sans lui, ShelfOpenAt + revealDelay).
function Logic.stopAt(openAt: number, luck: number, revealAt: number?): number
	return revealAt or (openAt + ShelfOpenState.revealDelay(luck))
end

-- Marge des calculs de tic : à ShelfRevealAt pile, le nombre de tics tombe parfois juste sous l'entier
-- (23,999…) et luckAt rendrait un tic de moins que la chance tirée.
local EPSILON = 1e-6

-- Chance affichée à `now` : ShelfOpenState.luckAt, figée à ShelfRevealAt (police appelée : arrêtée là).
function Logic.shownLuck(openAt: number, luck: number, revealAt: number?, now: number): number
	return ShelfOpenState.luckAt(openAt, luck, math.min(now, Logic.stopAt(openAt, luck, revealAt)) + EPSILON)
end

-- Numéro du tic affiché à `now` (0 avant le premier), borné au nombre de tics de la chance tirée.
function Logic.tickIndex(openAt: number, luck: number, revealAt: number?, now: number): number
	local t = math.min(now, Logic.stopAt(openAt, luck, revealAt)) + EPSILON - openAt - ShelfOpen.FlapsTime
	if not (t > 0) then
		return 0
	end
	return math.floor(ShelfOpenState.tickProgress(luck, t))
end

-- Part de la montée (k, 0 sans chance, 1 à la plus forte chance de la table), en échelle log : chaque tic
-- fait grandir le colis d'autant (V0 : l'aperçu prenait la chance finale de sa démo comme haut).
function Logic.growth(luck: number): number
	if not (luck > 1) or not (Logic.MaxLuck > 1) then
		return 0
	end
	return math.clamp(math.log(luck) / math.log(Logic.MaxLuck), 0, 1)
end

-- Échelle du colis : 1 + 0,6 × k, × le battement (+ 4 % au tic, retombé en fin de tic). `phase` = part
-- du tic en cours (0 à 1) ; nil = pas de battement.
function Logic.boxScale(k: number, phase: number?): number
	local beat = if phase then 1 + Logic.Beat * math.max(0, math.cos(math.clamp(phase, 0, 1) * math.pi)) else 1
	return (1 + Logic.Grow * k) * beat
end

-- Hauteur du tic (PlaybackSpeed relatif) : une octave sur toute la montée, de ×1 au premier tic à ×2 au dernier.
function Logic.tickPitch(index: number, total: number): number
	if total <= 1 then
		return 1
	end
	return 2 ^ (math.clamp((index - 1) / (total - 1), 0, 1))
end

-- Angle de bascule des rabats (ou du Lid) à `elapsed` s du lancement.
function Logic.flapAngle(elapsed: number): number
	return Logic.FlapAngle * Logic.backOut(elapsed / Logic.FlapTime)
end

-- Ce qui s'ouvre sur ce colis : ses rabats FlapL et FlapR (dans Lid) s'ils existent tous les deux, sinon le
-- Lid entier, sinon rien.
export type LidPlan = {
	Mode: string, -- "Flaps", "Lid" ou "None"
	Parts: { Instance },
}

local function movable(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Model") or instance:IsA("BasePart"))
end

function Logic.lidPlan(box: Instance): LidPlan
	local lid = box:FindFirstChild("Lid")
	if lid then
		local left = lid:FindFirstChild("FlapL", true)
		local right = lid:FindFirstChild("FlapR", true)
		if movable(left) and movable(right) then
			return { Mode = "Flaps", Parts = { left :: Instance, right :: Instance } }
		end
		if movable(lid) then
			return { Mode = "Lid", Parts = { lid } }
		end
	end
	return { Mode = "None", Parts = {} }
end

-- Ligne Mutation de BB_Item : « BIG GOLD », « HUGE », « RAINBOW » ; nil sans mutation (ligne cachée).
function Logic.mutationText(size: any, effect: any): string?
	local parts: { string } = {}
	local sizeEntry = if type(size) == "string" then Mutations.SizeById[size] else nil
	local effectEntry = if type(effect) == "string" then Mutations.EffectById[effect] else nil
	if sizeEntry then
		table.insert(parts, sizeEntry.DisplayNameUpper)
	end
	if effectEntry then
		table.insert(parts, effectEntry.DisplayNameUpper)
	end
	return if #parts > 0 then table.concat(parts, " ") else nil
end

-- Voile UI_HUD.RevealTint pour cette rareté (Épique et plus, ShelfOpen.RevealTintMinRarity).
function Logic.wantsTint(rarityId: any): boolean
	local rarity = if type(rarityId) == "string" then Rarities.ById[rarityId] else nil
	local min = Rarities.ById[ShelfOpen.RevealTintMinRarity]
	return rarity ~= nil and min ~= nil and rarity.Order >= min.Order
end

-- Couleur de la rareté (blanc si inconnue).
function Logic.rarityColor(rarityId: any): Color3
	local rarity = if type(rarityId) == "string" then Rarities.ById[rarityId] else nil
	return if rarity then rarity.Color else Color3.new(1, 1, 1)
end

-- Ce joueur peut-il prendre l'objet sorti à `now` ? L'ouvreur toujours, les autres une fois la réservation
-- passée (attributs absents : tout le monde). Le serveur revérifie.
function Logic.canTake(reservedBy: any, reservedUntil: any, userId: number, now: number): boolean
	if type(reservedUntil) ~= "number" or now >= reservedUntil then
		return true
	end
	return reservedBy == userId
end

return Logic

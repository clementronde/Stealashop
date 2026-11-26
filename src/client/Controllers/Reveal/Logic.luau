--!strict
-- Reveal/Logic (client, vague 62, a204 ; L-198) : calculs sans Roblox de la cinématique d'ouverture (RevealController).
-- Module d'aide (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Reveal.

local Logic = {}

export type SizeClass = "Small" | "Large" | "Colossal"

export type Payload = {
	Opener: Player?,
	ShopId: string,
	SlotName: string,
	ItemId: string,
	Rarity: string,
	Mutation: string?,
	Weight: number,
	Scale: number,
	SizeClass: SizeClass,
	RevealId: string,
	Plan: string?, -- vague 73 (a251, L-236) : plan de la nouvelle ouverture (Shared/UnboxPlan), absent : cinématique d'avant
	Income: number?, -- a493 : $/s de l'objet calculé par le serveur (celui de la boutique) ; absent : calcul du client
}

local function finite(value: any, default: number): number
	if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
		return value
	end
	return default
end

function Logic.sizeClass(value: any): SizeClass
	if value == "Large" then
		return "Large"
	elseif value == "Colossal" then
		return "Colossal"
	end
	return "Small"
end

-- Le plafond saute-t-il pour cette classe ? (Cantin : seulement pour les gros objets)
function Logic.breaksCeiling(class: SizeClass): boolean
	return class == "Large" or class == "Colossal"
end

-- RevealStarted : arguments dans l'ordre de Net/Definitions, ou une seule table aux noms du contrat (L-198).
-- nil si l'envoi est inutilisable (pas de RevealId, d'ItemId ou de magasin).
function Logic.parse(first: any, ...: any): Payload?
	local t: { [string]: any }
	if type(first) == "table" and typeof(first) ~= "Instance" then
		t = first
	else
		local rest = table.pack(...)
		t = {
			Opener = first,
			ShopId = rest[1],
			SlotName = rest[2],
			ItemId = rest[3],
			Rarity = rest[4],
			Mutation = rest[5],
			Weight = rest[6],
			Scale = rest[7],
			SizeClass = rest[8],
			RevealId = rest[9],
			Plan = rest[10],
			Income = rest[11],
		}
	end
	local revealId, itemId, shopId = t.RevealId, t.ItemId, t.ShopId
	if type(revealId) ~= "string" or revealId == "" or type(itemId) ~= "string" or itemId == "" then
		return nil
	end
	if type(shopId) ~= "string" then
		return nil
	end
	local mutation = t.Mutation
	local opener: any = t.Opener
	local player: Player? = nil
	if typeof(opener) == "Instance" then
		local inst: Instance = opener
		if inst:IsA("Player") then
			player = inst :: Player
		end
	end
	return {
		Opener = player,
		ShopId = shopId,
		SlotName = if type(t.SlotName) == "string" then t.SlotName else "",
		ItemId = itemId,
		Rarity = if type(t.Rarity) == "string" then t.Rarity else "Common",
		Mutation = if type(mutation) == "string" and mutation ~= "" then mutation else nil,
		Weight = math.max(finite(t.Weight, 0), 0),
		Scale = math.clamp(finite(t.Scale, 1), 0.05, 100),
		SizeClass = Logic.sizeClass(t.SizeClass),
		RevealId = revealId,
		Plan = if type(t.Plan) == "string" and t.Plan ~= "" then t.Plan else nil,
		Income = if type(t.Income) == "number" and t.Income == t.Income and t.Income >= 0 and t.Income < math.huge
			then t.Income
			else nil,
	}
end

-- Nom de l'Attachment du rayon : « ShelfSlot_03 » tel quel, ou tiré du SlotId « <StoreId>/03 ».
function Logic.slotAttachment(slot: string): string
	local number = string.match(slot, "/(%d+)$")
	if number then
		return string.format("ShelfSlot_%02d", tonumber(number) or 0)
	end
	return slot
end

-- « 1 250 kg » ; sous 10 kg, un chiffre après la virgule (« 4.5 kg »).
function Logic.formatWeight(kg: number): string
	if kg < 10 then
		local text = string.format("%.1f", kg)
		text = string.gsub(text, "%.0$", "")
		return `{text} kg`
	end
	local digits = tostring(math.floor(kg + 0.5))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1 ")))
	grouped = string.gsub(grouped, "^ ", "")
	return `{grouped} kg`
end

-- Courbes (0 → 1).
function Logic.easeInOut(f: number): number
	f = math.clamp(f, 0, 1)
	return (1 - math.cos(math.pi * f)) / 2
end

function Logic.backOut(f: number): number
	f = math.clamp(f, 0, 1)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (f - 1) ^ 3 + c1 * (f - 1) ^ 2
end

-- Taille montrée pendant la croissance : de `from` à `to`, fraction `f` de Grow à Top.
function Logic.growScale(from: number, to: number, f: number): number
	return from + (to - from) * Logic.easeInOut(f)
end

-- Taille de départ de la croissance : StartScale, ou la taille finale si elle est plus petite (objet léger).
function Logic.startScale(final: number, start: number): number
	return math.min(final, start)
end

export type Timeline = {
	Open: { [string]: number }, -- marqueur → instant (s depuis le début de l'étape)
	OpenEnd: number,
	Grow: { [string]: number },
	GrowEnd: number,
}

-- Instants du repli codé (Config/Reveal.Fallback) pour une classe.
function Logic.fallback(fallback: any, class: SizeClass): Timeline
	local growTime: number = fallback.GrowTime[class] or fallback.GrowTime.Small
	local land: number = fallback.LandHold[class] or fallback.LandHold.Small
	local grow: { [string]: number } = { Grow = 0, Top = growTime, Land = growTime + land }
	if Logic.breaksCeiling(class) then
		grow.Explode = growTime * fallback.ExplodeAt
	end
	return {
		Open = { Open = fallback.OpenAt, Reveal = fallback.RevealAt },
		OpenEnd = fallback.OpenEnd,
		Grow = grow,
		GrowEnd = growTime + land,
	}
end

-- Marqueurs attendus d'une étape, dans l'ordre ; ceux qui ne sont pas passés tombent à la fin de l'animation, dans cet
-- ordre (Explode, absent : à Top).
function Logic.markers(stage: "Open" | "Grow", class: SizeClass): { string }
	if stage == "Open" then
		return { "Open", "Reveal" }
	end
	if Logic.breaksCeiling(class) then
		return { "Grow", "Explode", "Top", "Land" }
	end
	return { "Grow", "Top", "Land" }
end

-- Écart caméra ↔ ancre (espace de l'ancre) multiplié par la taille de l'objet : la position s'éloigne, l'orientation
-- reste celle de l'animation.
function Logic.scaledOffset(offset: CFrame, scale: number): CFrame
	return CFrame.new(offset.Position * scale) * offset.Rotation
end

return Logic

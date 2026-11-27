-- FX_Fireworks : 260 particules et une gerbe plus basse (Clément, 26/11 : « 260, et plus bas »)
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est créé.
-- Part des valeurs d'origine sauvées dans ServerStorage/MapBackups/2026-11-26_FX_Allege/FX_Fireworks (640 particules),
-- pour qu'on puisse relancer ce script sans tout réduire deux fois.
--   Gerbe à 60 studs au lieu de 90 (confettis à 25 au lieu de 35) ; la fusée monte moins vite pour y arriver
--   au même moment (RiseTime 1,1 inchangé) : vitesses de Launch × 60/90.
--   Nombres : 640 → 266 (Crackle compris ; 216 sans lui, s'il ne part qu'à partir de Légendaire).

local FX = game.ReplicatedStorage.Assets.FX
local fw = FX.FX_Fireworks
local bk = game.ServerStorage.MapBackups["2026-11-26_FX_Allege"].FX_Fireworks

local HEIGHT, OLD_HEIGHT = 60, 90
local K = HEIGHT / OLD_HEIGHT
local COUNTS = { -- EmitCount visé et facteur de taille
	["Launch/Trail"] = { 28, 1.15 }, ["Launch/TrailSmoke"] = { 22, 1.15 },
	["Burst/Stars"] = { 58, 1.2 }, ["Burst/Streaks"] = { 32, 1.15 }, ["Burst/Crackle"] = { 50, 1.15 },
	["Burst/Smoke"] = { 10, 1.1 },
	["Confetti/Confetti_Rarity"] = { 20, 1.1 }, ["Confetti/Confetti_Red"] = { 14, 1.1 },
	["Confetti/Confetti_Blue"] = { 14, 1.1 }, ["Confetti/Confetti_White"] = { 14, 1.1 },
}

local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for name in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(name, true)
	end
	return node
end
local function scaled(seq: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in seq.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

for path, v in COUNTS do
	local e, o = find(fw, path), find(bk, path)
	if e and o and e:IsA("ParticleEmitter") and o:IsA("ParticleEmitter") then
		e:SetAttribute("EmitCount", v[1])
		e.Size = scaled(o.Size, v[2])
	else
		warn("[fx_fireworks_260] absent : " .. path)
	end
end
-- hauteur : la gerbe et les confettis descendent, la fusée ralentit d'autant
local burst = find(fw, "Burst")
local conf = find(fw, "Confetti")
if burst and burst:IsA("Attachment") then burst.Position = Vector3.new(0, HEIGHT, 0) end
if conf and conf:IsA("Attachment") then conf.Position = Vector3.new(0, 35 * K, 0) end
for _, n in { "Head", "Trail", "TrailSmoke" } do
	local e, o = find(fw, "Launch/" .. n), find(bk, "Launch/" .. n)
	if e and o and e:IsA("ParticleEmitter") and o:IsA("ParticleEmitter") then
		e.Speed = NumberRange.new(o.Speed.Min * K, o.Speed.Max * K)
	end
end

local total = 0
for _, d in fw:GetDescendants() do
	if d:IsA("ParticleEmitter") then total += d:GetAttribute("EmitCount") or 0 end
end
print("[fx_fireworks_260] " .. total .. " particules, gerbe à " .. HEIGHT .. " studs")
return total

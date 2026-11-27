-- Allègement des effets lourds (repasse qualité du 26/11, chef VFX et son)
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est créé.
-- Principe : moins de particules mais un peu plus grosses, pour garder la forme et la couverture.
--   nombre × f, taille × t (t ≈ f^-0,25 environ) ; les durées, couleurs, vitesses et textures ne changent pas.
-- Sauvegarde d'abord : ServerStorage/MapBackups/2026-11-26_FX_Allege (copies des 4 effets et du tapis Fire).
-- Pour revenir en arrière : remettre les copies de la sauvegarde à leur place.

local FX = game.ReplicatedStorage.Assets.FX
local PLOTS = game.ReplicatedStorage.Assets.Plots

-- EmitCount visés et facteur de taille, par émetteur (chemin depuis le modèle)
local BURSTS = {
	FX_RevealSmash = { -- 221 → 69
		["Root/Base/DebrisKraft"] = { 7, 1.3 }, ["Root/Base/Bits"] = { 8, 1.35 }, ["Root/Base/Dust"] = { 8, 1.15 },
		["Root/Top/Plaster"] = { 8, 1.35 }, ["Root/Top/CeilingDust"] = { 5, 1.15 },
		["Root/Glass/GlassShards"] = { 10, 1.3 }, ["Root/Glass/GlassSparkle"] = { 6, 1.2 },
		["Root/Side/DebrisWood"] = { 7, 1.3 }, ["Root/Side/DebrisLight"] = { 5, 1.3 }, ["Root/Side/SideDust"] = { 4, 1.15 },
	},
	FX_ShopGlass_Burst = { -- 122 → 58
		["Root/Out/Shards"] = { 22, 1.25 }, ["Root/Out/Splinters"] = { 12, 1.3 }, ["Root/Out/Glitter"] = { 12, 1.2 },
		["Root/Out/GlassDust"] = { 5, 1.1 }, ["Root/In/ShardsBack"] = { 6, 1.2 },
	},
	FX_ShelfReveal = { -- 117 → 53
		["Root/Center/Streaks"] = { 16, 1.15 }, ["Root/Center/Confetti"] = { 26, 1.2 }, ["Root/Center/Stars"] = { 10, 1.2 },
	},
	FX_Fireworks = { -- 640 → 182 (146 sans le crépitement, qui ne doit partir qu'à partir de Légendaire)
		["Root/Launch/Trail"] = { 18, 1.25 }, ["Root/Launch/TrailSmoke"] = { 14, 1.25 },
		["Root/Burst/Stars"] = { 36, 1.3 }, ["Root/Burst/Streaks"] = { 22, 1.25 }, ["Root/Burst/Crackle"] = { 36, 1.25 },
		["Root/Burst/Smoke"] = { 8, 1.15 },
		["Root/Confetti/Confetti_Rarity"] = { 14, 1.15 }, ["Root/Confetti/Confetti_Red"] = { 10, 1.15 },
		["Root/Confetti/Confetti_Blue"] = { 10, 1.15 }, ["Root/Confetti/Confetti_White"] = { 10, 1.15 },
	},
}
-- Tapis Fire : tous les émetteurs allumés en continu, Rate × 0,2 et taille × 1,25 (241 → ≈ 48 particules vivantes)
local FIRE_RATE, FIRE_SIZE = 0.2, 1.25

local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for name in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function scaleSize(e: ParticleEmitter, k: number)
	local kps = {}
	for _, p in e.Size.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	e.Size = NumberSequence.new(kps)
end

local function live(m: Instance): number
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			n += (d:GetAttribute("EmitCount") or 0) + (if d.Enabled then d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2 else 0)
		end
	end
	return n
end

-- Sauvegarde (une seule fois : on ne l'écrase pas si elle existe déjà)
local backups = game.ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = game.ServerStorage
local bk = backups:FindFirstChild("2026-11-26_FX_Allege")
if not bk then
	bk = Instance.new("Folder")
	bk.Name = "2026-11-26_FX_Allege"
	for name in BURSTS do
		FX[name]:Clone().Parent = bk
	end
	PLOTS.PLOT_Treadmill_Fire:Clone().Parent = bk
	bk.Parent = backups
end

local report = {}
for name, list in BURSTS do
	local m = FX[name]
	local before = live(m)
	for path, v in list do
		local e = find(m, path)
		if e and e:IsA("ParticleEmitter") then
			-- part de la sauvegarde pour pouvoir relancer le script sans tout réduire deux fois
			local saved = bk:FindFirstChild(name)
			local orig = saved and find(saved, path)
			e:SetAttribute("EmitCount", v[1])
			if orig and orig:IsA("ParticleEmitter") then
				e.Size = orig.Size
				scaleSize(e, v[2])
			end
		else
			table.insert(report, "ABSENT " .. name .. "/" .. path)
		end
	end
	table.insert(report, string.format("%s : %d → %d", name, before, live(m)))
end

local fire = PLOTS.PLOT_Treadmill_Fire
local fireBk = bk:FindFirstChild("PLOT_Treadmill_Fire") :: Instance
local before = live(fire)
for _, e in fire:GetDescendants() do
	if e:IsA("ParticleEmitter") and e.Enabled then
		local rel = e:GetFullName():sub(#fire:GetFullName() + 2):gsub("%.", "/")
		local orig = find(fireBk, rel)
		if orig and orig:IsA("ParticleEmitter") then
			e.Rate = orig.Rate * FIRE_RATE
			e.Size = orig.Size
			scaleSize(e, FIRE_SIZE)
		end
	end
end
table.insert(report, string.format("PLOT_Treadmill_Fire : %d → %d", before, live(fire)))
print("[fx_allege] " .. table.concat(report, " ; "))
return table.concat(report, "\n")

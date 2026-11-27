-- Éclats du colis : vraie texture d'éclat et couleur de la rareté (repasse qualité du 26/11, chef VFX et son)
-- Constat du chef vidéo : à l'ouverture, les éclats étaient des carrés blancs et plats, sans la couleur de la rareté.
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est créé.
-- Sauvegarde d'abord : ServerStorage/MapBackups/2026-11-26_Unbox_Eclats (FX_Unbox_Reveal et FX_Unbox_Burst).
--   FX_Unbox_Reveal.ConfettiColor → éclats FX_Unbox_Shard (planche 2×2, une image au hasard par éclat), ×14
--   FX_Unbox_Reveal.Confetti      → confettis teintés par la rareté (RarityColor) qui volettent (Squash qui ondule), ×14
--   FX_Unbox_Reveal.Sparks        18 → 12
--   FX_Unbox_Burst.DebrisTape     → éclats FX_Unbox_Shard (garde RarityColor et ses 5 particules)
-- FX_Unbox_Reveal : 70 → 42 particules. Le code (Reveal/Unbox, emitAll) teint déjà tout émetteur qui porte RarityColor.

local SHARD = "rbxassetid://116795364510621" -- image de FX_Unbox_Shard (Decal 134142913806057, groupe RoundStone Studio)
local FX = game.ReplicatedStorage.Assets.FX

local backups = game.ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = game.ServerStorage
local bk = backups:FindFirstChild("2026-11-26_Unbox_Eclats")
if not bk then
	bk = Instance.new("Folder")
	bk.Name = "2026-11-26_Unbox_Eclats"
	FX.FX_Unbox_Reveal:Clone().Parent = bk
	FX.FX_Unbox_Burst:Clone().Parent = bk
	bk.Parent = backups
end

local function scaled(seq: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in seq.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end
local FLUTTER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1, 0.6), NumberSequenceKeypoint.new(0.2, -0.5),
	NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(0.4, -0.5), NumberSequenceKeypoint.new(0.5, 0.6),
	NumberSequenceKeypoint.new(0.6, -0.5), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(0.8, -0.5),
	NumberSequenceKeypoint.new(0.9, 0.6), NumberSequenceKeypoint.new(1, 0),
})
local function shard(e: ParticleEmitter)
	e.Texture = SHARD
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(0.5) -- presque fixe : chaque éclat garde sa forme
	e.FlipbookStartRandom = true
	e.LightEmission = 0.2 -- garde son contour sombre lisible de jour
	e.LightInfluence = 0.6
	e.Squash = NumberSequence.new(0)
end

local function src(model: string, name: string): ParticleEmitter?
	local m = bk:FindFirstChild(model)
	local e = m and m:FindFirstChild(name, true)
	return if e and e:IsA("ParticleEmitter") then e else nil
end

local out = {}
local reveal = FX.FX_Unbox_Reveal
local cc = reveal:FindFirstChild("ConfettiColor", true)
local co = reveal:FindFirstChild("Confetti", true)
local sp = reveal:FindFirstChild("Sparks", true)
local ccSrc, coSrc = src("FX_Unbox_Reveal", "ConfettiColor"), src("FX_Unbox_Reveal", "Confetti")
if cc and cc:IsA("ParticleEmitter") and ccSrc then
	shard(cc)
	cc.Size = scaled(ccSrc.Size, 1.35)
	cc:SetAttribute("EmitCount", 14)
	cc:SetAttribute("RarityColor", true)
	table.insert(out, "ConfettiColor → éclats ×14")
end
if co and co:IsA("ParticleEmitter") and coSrc then
	co.Size = scaled(coSrc.Size, 1.2)
	co.Squash = FLUTTER
	co:SetAttribute("EmitCount", 14)
	co:SetAttribute("RarityColor", true)
	table.insert(out, "Confetti → teintés, volettent ×14")
end
if sp and sp:IsA("ParticleEmitter") then
	sp:SetAttribute("EmitCount", 12)
	table.insert(out, "Sparks ×12")
end
local tape = FX.FX_Unbox_Burst:FindFirstChild("DebrisTape", true)
local tapeSrc = src("FX_Unbox_Burst", "DebrisTape")
if tape and tape:IsA("ParticleEmitter") and tapeSrc then
	shard(tape)
	tape.Size = scaled(tapeSrc.Size, 1.3)
	tape:SetAttribute("RarityColor", true)
	table.insert(out, "Burst.DebrisTape → éclats")
end
local n = 0
for _, d in reveal:GetDescendants() do
	if d:IsA("ParticleEmitter") then n += d:GetAttribute("EmitCount") or 0 end
end
table.insert(out, "FX_Unbox_Reveal : " .. n .. " particules")
print("[fx_unbox_eclats] " .. table.concat(out, " ; "))
return table.concat(out, "\n")

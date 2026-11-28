-- L-503 (Cantin, 28/11, test T-450) : pose d'un objet sur un présentoir, l'éclat blanc et les étoiles d'au moins
-- 2 fois plus grands. Chef VFX et son. À coller en Edit ; relançable (on repart des valeurs gardées en attributs
-- Orig*). Sauvegarde : ServerStorage/MapBackups/2026-11-28_FX_DisplayPlace. Aucun nom ne change.
--   Root/Burst/Stars : taille × 2,2 (0,5 → 1,1 stud au plus), vitesse × 1,3 (elles vont plus loin, pour rester
--   lisibles autour d'un objet plus grand), durée de vie gardée.
--   Root/Burst/Glint : taille × 2,2 (1,3 → 2,9 studs).
local SS = game:GetService("ServerStorage")
local fx = game.ReplicatedStorage.Assets.FX:FindFirstChild("FX_DisplayPlace")
assert(fx, "Assets/FX/FX_DisplayPlace absent")
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-28_FX_DisplayPlace") then
	local b = fx:Clone()
	b.Name = "2026-11-28_FX_DisplayPlace"
	b.Parent = backups
end
local SIZE, SPEED = 2.2, 1.3
local function scaled(seq: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in seq.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k)) end
	return NumberSequence.new(kps)
end
local out = {}
for _, name in { "Stars", "Glint" } do
	local e = fx:FindFirstChild(name, true)
	if e and e:IsA("ParticleEmitter") then
		if e:GetAttribute("OrigSize") == nil then
			e:SetAttribute("OrigSize", e.Size)
			e:SetAttribute("OrigSpeed", e.Speed)
		end
		e.Size = scaled(e:GetAttribute("OrigSize") :: NumberSequence, SIZE)
		if name == "Stars" then
			local s = e:GetAttribute("OrigSpeed") :: NumberRange
			e.Speed = NumberRange.new(s.Min * SPEED, s.Max * SPEED)
		end
		local mx = 0
		for _, p in e.Size.Keypoints do mx = math.max(mx, p.Value) end
		table.insert(out, string.format("%s : taille max %.2f, vitesse %.1f à %.1f", name, mx, e.Speed.Min, e.Speed.Max))
	else
		table.insert(out, name .. " ABSENT")
	end
end
return table.concat(out, "\n")

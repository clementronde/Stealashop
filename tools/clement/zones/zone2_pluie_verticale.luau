-- zone2_pluie_verticale.luau — pluie de Londres (zone 2) qui tombait à l'horizontale (Clément, 2026-11-20)
-- Cause : en Orientation VelocityParallel, un Squash positif étire la goutte en travers
-- de sa course ; il faut un Squash négatif pour l'étirer dans le sens de la chute.
-- Corrige la pluie (RainCloud.Rain, Squash 3 -> -3) et les gouttes des auvents
-- (AwningDrips_*.Drips, 1.5 -> -1.5). Rejouable : le signe est forcé à négatif.
-- À exécuter en Edit (barre de commande ou MCP execute_luau).

local weather = workspace.Map.Zone_2.Street_Londres.Weather
for _, d in ipairs(weather:GetDescendants()) do
	if d:IsA("ParticleEmitter") and d.Orientation == Enum.ParticleOrientation.VelocityParallel then
		local kps = {}
		for _, k in ipairs(d.Squash.Keypoints) do
			table.insert(kps, NumberSequenceKeypoint.new(k.Time, -math.abs(k.Value), k.Envelope))
		end
		d.Squash = NumberSequence.new(kps)
		print(d:GetFullName(), "Squash =", d.Squash.Keypoints[1].Value)
	end
end

-- Banc a129 (vague 39, 2026-11-14), scénario « halo » : inséré dans le banc a14 (copie a129) juste avant sa
-- section 11, sur sa boutique (Alice, caméra en (0, 5, 30) qui regarde vers −Z, objets à 26-38 studs).
-- Config/DisplayHalo : lumière et particules éteintes au-delà de 50 studs (rallumées sous 50, écart de 5),
-- rien quand VISUAL EFFECTS est sur OFF, rayons tournés seulement à l'écran, teintes du Secret réutilisées.
print("== 10 bis. a129 : halos des objets exposés sur téléphone")
do
	local Halo = requireModule(Shared:FindFirstChild("Config"):FindFirstChild("DisplayHalo"), "client")
	local nearCF = CFrame.new(0, 5, 30)
	-- Sauf l'objet exposé par PlaceItem en section 10 (présentoir `free`) : dans ce faux Roblox, son tag arrive
	-- avant son rangement dans la parcelle et DisplayController l'ignore (déjà avant la vague 39) ; dans le
	-- jeu, le client le reçoit déjà rangé.
	local placedLate = item(plot1, free)
	local function haloParts()
		local list = {}
		for _, model in CollectionServiceStub:GetTagged("DisplayItem") do
			local halo = model ~= placedLate and model:FindFirstChild("RarityHalo")
			if halo then
				table.insert(list, halo)
			end
		end
		return list
	end
	local function allEffects(on)
		local n, good = 0, true
		for _, halo in haloParts() do
			for _, name in { "HaloLight", "HaloSparkles" } do
				local effect = halo:FindFirstChild(name)
				if effect then
					n += 1
					if effect.Enabled ~= on then
						good = false
					end
				end
			end
		end
		return good and n > 0, n
	end
	check(Halo.EffectsDistance == 50 and Halo.EffectsMargin == 5 and Halo.RaysOnScreenOnly == true and Halo.RainbowSteps == 120, "Config/DisplayHalo : valeurs V0 (50, 5, rayons à l'écran, 120 teintes)")

	camera.CFrame = nearCF
	step(0.3)
	local ok, n = allEffects(true)
	check(ok, `caméra à moins de 50 studs : lumière et particules de chaque halo allumées ({n} effets)`)

	camera.CFrame = CFrame.new(1000, 5, 1000)
	step(0.3)
	ok, n = allEffects(false)
	check(ok, `caméra à plus de 55 studs : lumière et particules éteintes ({n} effets)`)
	local beamOn = secret6Halo:FindFirstChild("Ray_01"):FindFirstChild("RayBeam").Enabled
	check(beamOn == true, "les rayons (Beam) ne sont pas coupés au loin")

	-- Écart de 5 studs : rallumée sous 50, éteinte au-delà de 55, inchangée entre les deux.
	local light = secret6Halo:FindFirstChild("HaloLight")
	local sparkles = secret6Halo:FindFirstChild("HaloSparkles")
	local center = secret6Halo.Position
	camera.CFrame = CFrame.new(center + Vector3.new(0, 0, 52))
	step(0.3)
	check(light.Enabled == false, "à 52 studs en venant de loin : reste éteinte (écart)")
	camera.CFrame = CFrame.new(center + Vector3.new(0, 0, 48))
	step(0.3)
	check(light.Enabled == true and sparkles.Enabled == true, "à 48 studs : rallumées")
	camera.CFrame = CFrame.new(center + Vector3.new(0, 0, 53))
	step(0.3)
	check(light.Enabled == true, "à 53 studs en venant de près : reste allumée (écart)")
	camera.CFrame = CFrame.new(center + Vector3.new(0, 0, 56))
	step(0.3)
	check(light.Enabled == false and sparkles.Enabled == false, "à 56 studs : éteintes")

	-- VISUAL EFFECTS sur OFF : CosmeticController (pas lancé ici) éteint tout ; DisplayController n'y touche pas.
	alice:SetAttribute("VfxEnabled", false)
	camera.CFrame = nearCF
	step(0.3)
	check(light.Enabled == false, "VISUAL EFFECTS OFF : la coupure ne rallume rien, même de près")
	light.Enabled = true -- comme si CosmeticController rendait l'état d'origine au loin
	camera.CFrame = CFrame.new(1000, 5, 1000)
	step(0.3)
	check(light.Enabled == true, "VISUAL EFFECTS OFF : la coupure n'éteint rien non plus")
	alice:SetAttribute("VfxEnabled", true)
	step(0.3)
	check(light.Enabled == false, "VISUAL EFFECTS ON : l'état voulu revient au passage suivant (loin : éteinte)")
	camera.CFrame = nearCF
	step(0.3)
	check(light.Enabled == true, "puis de près : rallumée")

	-- Rayons tournés seulement dans le champ de la caméra.
	local ray = secret6Halo:FindFirstChild("Ray_01")
	local start = ray.Position
	step(0.3)
	check(not (ray.Position == start), "halo à l'écran : les rayons tournent")
	camera.CFrame = nearCF * CFrame.Angles(0, math.pi, 0) -- même place, regarde vers +Z : halos dans le dos
	local frozen = ray.Position
	local lightColor = light.Color
	step(0.3)
	check(ray.Position == frozen, "halo hors champ (dans le dos) : rayons pas tournés")
	check(not (light.Color == lightColor), "hors champ : la lumière du Secret change toujours de couleur (elle éclaire autour)")
	-- Champ du faux : 70° en hauteur, 16/9 : demi-angle horizontal ≈ 51°. Lacet vers le halo (regard −Z à 0).
	local dir = center - nearCF.Position
	local yaw = math.atan2(-dir.X, -dir.Z)
	camera.CFrame = nearCF * CFrame.Angles(0, yaw + math.rad(45), 0) -- halo à 45° du centre du champ
	local edge = ray.Position
	step(0.3)
	check(not (ray.Position == edge), "halo au bord du champ (à 45°) : rayons tournés")
	camera.CFrame = nearCF * CFrame.Angles(0, yaw + math.rad(54), 0) -- centre à 54° : ses rayons touchent encore le champ
	edge = ray.Position
	step(0.3)
	check(not (ray.Position == edge), "centre du halo juste hors champ (54°), rayons dedans : tournés")
	camera.CFrame = nearCF * CFrame.Angles(0, yaw + math.rad(80), 0) -- halo à 80° : hors champ
	edge = ray.Position
	step(0.3)
	check(ray.Position == edge, "halo à 80° du centre : hors champ, rayons pas tournés")
	camera.CFrame = nearCF
	step(0.1)
	local radius0 = (ray.Position - secret6Halo:FindFirstChild("RaysCenter").Position).Magnitude
	check(radius0 > 0 and near(radius0, (start - secret6Halo:FindFirstChild("RaysCenter").Position).Magnitude, 1e-6), "de retour à l'écran : même longueur de rayon")

	-- Teintes du Secret calculées une fois : en 10 images d'1 ms, au plus 2 ColorSequence différentes sur
	-- un rayon (avant : une neuve par image), et la couleur défile toujours.
	local beam = ray:FindFirstChild("RayBeam")
	local seen, distinct = {}, 0
	for _ = 1, 10 do
		step(0.001, 1000)
		local color = beam.Color
		if not seen[color] then
			seen[color] = true
			distinct += 1
		end
	end
	check(distinct <= 2, `10 images d'1 ms : {distinct} ColorSequence (teintes réutilisées)`)
	local first = beam.Color
	step(0.5)
	check(not rawequal(beam.Color, first) and not (beam.Color.Keypoints[1].Value == first.Keypoints[1].Value), "en 0,5 s : la couleur du rayon du Secret a changé (arc-en-ciel qui défile)")
	local legendaryBeam = ticketHalo:FindFirstChild("Ray_01"):FindFirstChild("RayBeam")
	check(legendaryBeam.Color.Keypoints[1].Value == rarityColor("Legendary"), "rayons du Légendaire : toujours dorés")
	camera.CFrame = nearCF
end

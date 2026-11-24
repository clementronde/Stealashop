print("\n== V. VISUAL EFFECTS sur OFF (a73, vague 24) : ce qui est éteint, ce qui reste")
do
	-- Classes absentes du faux Roblox d'a20 (ajout pur).
	ISA.Beam = ISA.Beam or {}
	PROPS.Beam = PROPS.Beam or { Enabled = true, Attachment0 = NONE, Attachment1 = NONE }
	ISA.Highlight = ISA.Highlight or {}
	PROPS.Highlight = PROPS.Highlight or { Enabled = true }
	-- Une seule aura et un seul trail par joueur ici : Bob (P2) les a ; Alice (P1, joueur local) aussi.
	CosmeticService.Equip(P2, "Spark")
	step(0.6)
	local aura2 = aurasOf(char2)[1]
	local trail2 = root2:FindFirstChild("CosmeticTrail")
	local auraLight = aura2 and aura2:FindFirstChildWhichIsA("PointLight")
	-- Halo d'un colis porté (CarryService : Attachment HaloPoint) et d'un objet exposé (DisplayService : RarityHalo).
	local box = new("Part", { Name = "Box", CFrame = CFrame.new(-14, 3, -10) }, Workspace)
	local point = new("Attachment", { Name = "HaloPoint" }, box)
	local haloLight = new("PointLight", {}, point)
	local haloSparkles = new("ParticleEmitter", { Name = "HaloSparkles" }, point)
	local haloRay = new("Beam", { Name = "HaloRay_1" }, point)
	local display = new("Part", { Name = "RarityHalo", CFrame = CFrame.new(-10, 3, -10) }, Workspace)
	local displayLight = new("PointLight", { Name = "HaloLight" }, display)
	local displaySparkles = new("ParticleEmitter", { Name = "HaloSparkles" }, display)
	local rayBeam = new("Beam", { Name = "RayBeam" }, display)
	-- Gardés : contour utile, émetteur du décor de Clément, émetteur déjà éteint dans un halo.
	local outline = new("Highlight", { Name = "CarryOutline" }, box)
	local decor = new("Part", { Name = "Fountain" }, Workspace)
	local decorFx = new("ParticleEmitter", { Name = "Water" }, decor)
	local off = new("ParticleEmitter", { Name = "Sleeping", Enabled = false }, point)
	step(0.1)
	check(aura2 ~= nil and trail2 ~= nil and auraLight ~= nil and CosCtrl.CutCount() == 0, "V1 VISUAL EFFECTS sur ON : rien d'éteint")

	P1:SetAttribute("VfxEnabled", false)
	step(0.6)
	local allZero = true
	for _, e in aura2:GetChildren() do
		if e.ClassName == "ParticleEmitter" and not near(e.Rate, 0) then
			allZero = false
		end
	end
	check(allZero, "V2 OFF : auras des autres à débit nul (coupées)")
	local own = aurasOf(char1)[1]
	check(own == nil or near(own.AuraParticles.Rate, 0), "V3 OFF : la sienne aussi")
	check(auraLight.Enabled == false, "V4 OFF : lumière de l'aura éteinte")
	check(trail2.Enabled == false, "V5 OFF : trail des autres éteint")
	local ownTrail = root1:FindFirstChild("CosmeticTrail")
	check(ownTrail == nil or ownTrail.Enabled == false, "V6 OFF : son trail éteint")
	check(haloLight.Enabled == false and haloSparkles.Enabled == false and haloRay.Enabled == false, "V7 OFF : halo du colis (HaloPoint : lumière, paillettes, rayon) éteint")
	check(displayLight.Enabled == false and displaySparkles.Enabled == false and rayBeam.Enabled == false, "V8 OFF : halo de l'objet exposé (RarityHalo) éteint")
	check(outline.Enabled == true and decorFx.Enabled == true, "V9 OFF : contour Highlight et effets du décor gardés")
	local late = new("Part", { Name = "Box2" }, Workspace)
	local latePoint = new("Attachment", { Name = "HaloPoint" }, late)
	local lateSparkles = new("ParticleEmitter", { Name = "HaloSparkles" }, latePoint)
	step(0.1)
	check(lateSparkles.Enabled == false, "V10 OFF : halo arrivé ensuite (nouveau colis) éteint à son arrivée")

	P1:SetAttribute("VfxEnabled", true)
	step(0.6)
	check(near(aura2.AuraParticles.Rate, aura2.AuraParticles:GetAttribute("FullRate")) or near(aura2.AuraParticles.Rate, aura2.AuraParticles:GetAttribute("FullRate") * 0.5), "V11 ON : auras revenues (débit plein, ou moitié au loin)")
	check(auraLight.Enabled and trail2.Enabled and haloLight.Enabled and haloSparkles.Enabled and haloRay.Enabled and displayLight.Enabled and displaySparkles.Enabled and rayBeam.Enabled and lateSparkles.Enabled, "V12 ON : lumière, trails et halos rallumés")
	check(off.Enabled == false and CosCtrl.CutCount() == 0, "V13 ON : l'émetteur déjà éteint reste éteint, plus rien de coupé")
	local later = new("ParticleEmitter", { Name = "HaloSparkles" }, latePoint)
	step(0.1)
	check(later.Enabled == true, "V14 ON : un nouveau halo n'est plus touché")
end


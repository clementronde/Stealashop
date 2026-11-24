print("\n== W. Effets complets de Clément (a78, vague 26, L-097 point 1) : modèles FX_ copiés sur le perso")
do
	-- Classes absentes du faux Roblox d'a20 (ajout pur, comme a73).
	ISA.Beam = ISA.Beam or {}
	PROPS.Beam = PROPS.Beam or { Enabled = true, Attachment0 = NONE, Attachment1 = NONE }

	local function cf(x, y, z)
		return CFrame.new(x, y, z)
	end
	local function fxAttachments(character, kind)
		local out = {}
		for _, d in character:GetDescendants() do
			if d.ClassName == "Attachment" and d:GetAttribute("CosmeticFx") == kind then
				table.insert(out, d)
			end
		end
		return out
	end

	-- Modèles de Clément tels que relevés dans Studio (2026-11-11), en plus petit.
	local assets = ReplicatedStorage:FindFirstChild("Assets") or new("Folder", { Name = "Assets" }, ReplicatedStorage)
	local fx = assets:FindFirstChild("FX") or new("Folder", { Name = "FX" }, assets)
	new("Decal", { Name = "FX_Aura_Plasma", Texture = "rbxassetid://4004" }, fx) -- Decal homonyme, ignoré
	local plasma = new("Model", { Name = "FX_Aura_Plasma" })
	local mTorso = new("Part", { Name = "UpperTorso", Transparency = 1, Anchored = true }, plasma)
	local mRoot = new("Part", { Name = "HumanoidRootPart", Transparency = 1, Anchored = true }, plasma)
	local mHand = new("Part", { Name = "LeftHand", Transparency = 1, Anchored = true }, plasma)
	local mHead = new("Part", { Name = "Head", Transparency = 1, Anchored = true }, plasma)
	local coeur = new("Attachment", { Name = "Aura_Coeur", CFrame = cf(0, 0.5, 0) }, mTorso)
	new("ParticleEmitter", { Name = "Globe", Rate = 12 }, coeur)
	local haut = new("Attachment", { Name = "Aura_FilamentHaut1", CFrame = cf(0.3, 1, 0) }, mTorso)
	local sol = new("Attachment", { Name = "Aura_FilamentSol1", CFrame = cf(0.8, -3, 0) }, mRoot)
	new("ParticleEmitter", { Name = "Impact", Rate = 4 }, sol)
	local filament = new("Beam", { Name = "Filament", Attachment0 = haut, Attachment1 = sol }, haut)
	local lumiere = new("Attachment", { Name = "Aura_Lumiere" }, mTorso)
	new("PointLight", { Name = "Lumiere" }, lumiere)
	local poing = new("Attachment", { Name = "Aura_Poing", CFrame = cf(0, -0.2, 0) }, mHand)
	new("ParticleEmitter", { Name = "PoingPlasma", Rate = 6 }, poing)
	local tete = new("Attachment", { Name = "Aura_Tete" }, mHead)
	-- Rayon qui part du torse vers la tête : le perso du banc n'a pas de Head → rayon retiré.
	new("Beam", { Name = "VersTete", Attachment0 = coeur, Attachment1 = tete }, coeur)
	plasma.Parent = new("Folder", { Name = "Auras" }, fx)

	local hyper = new("Model", { Name = "FX_Trail_Hyperespace" })
	local tRoot = new("Part", { Name = "HumanoidRootPart", Transparency = 1, Anchored = true }, hyper)
	local tFoot = new("Part", { Name = "LeftFoot", Transparency = 1, Anchored = true }, hyper)
	local cHaut = new("Attachment", { Name = "Trail_CorpsHaut", CFrame = cf(0, 1, 0.6) }, tRoot)
	local cBas = new("Attachment", { Name = "Trail_CorpsBas", CFrame = cf(0, -1, 0.6) }, tRoot)
	new("Trail", { Name = "Distorsion", Attachment0 = cHaut, Attachment1 = cBas }, cHaut)
	local warp = new("Attachment", { Name = "Trail_Warp" }, tRoot)
	new("ParticleEmitter", { Name = "Distorsion", Rate = 9 }, warp)
	local rHaut = new("Attachment", { Name = "Trail_RayonHaut" }, tFoot)
	local rBas = new("Attachment", { Name = "Trail_RayonBas" }, tFoot)
	new("Trail", { Name = "Rayon", Attachment0 = rHaut, Attachment1 = rBas }, rHaut)
	hyper.Parent = new("Folder", { Name = "Trails" }, fx)

	-- Perso d'Alice (joueur local) avec quelques pièces R15 (pas de Head).
	local char = P1.Character
	local root = char.HumanoidRootPart
	local torso = new("Part", { Name = "UpperTorso", CFrame = root.CFrame * cf(0, 1, 0) }, char)
	local hand = new("Part", { Name = "LeftHand", CFrame = root.CFrame * cf(-1.5, 0, 0) }, char)
	local foot = new("Part", { Name = "LeftFoot", CFrame = root.CFrame * cf(-0.5, -2.8, 0) }, char)
	CosmeticService.Grant(P1, "Plasma")
	CosmeticService.Grant(P1, "Hyperspace")
	CosmeticService.Grant(P1, "Spark")
	CosmeticService.Equip(P1, "Plasma")
	step(0.1)

	local cCoeur = torso:FindFirstChild("Aura_Coeur")
	local cHautA = torso:FindFirstChild("Aura_FilamentHaut1")
	local cSol = root:FindFirstChild("Aura_FilamentSol1")
	local cPoing = hand:FindFirstChild("Aura_Poing")
	check(cCoeur ~= nil and cHautA ~= nil and cSol ~= nil and cPoing ~= nil and torso:FindFirstChild("Aura_Lumiere") ~= nil, "W1 Plasma : chaque Attachment copié sur la pièce de même nom (UpperTorso, HumanoidRootPart, LeftHand)")
	check(cCoeur.CFrame == coeur.CFrame and cSol.CFrame == sol.CFrame and cPoing.CFrame == poing.CFrame, "W2 CFrame relatif gardé")
	check(#aurasOf(char) == 0, "W3 modèle livré : pas d'aura V0 (pièce CosmeticAura)")
	local beam = cHautA:FindFirstChild("Filament")
	check(beam ~= nil and beam.Attachment0 == cHautA and beam.Attachment1 == cSol, "W4 Beam UpperTorso → HumanoidRootPart relié aux deux copies")
	check(filament.Attachment0 == haut and filament.Attachment1 == sol and haut.Parent == mTorso, "W5 modèle de Clément intact")
	check(cCoeur:FindFirstChild("VersTete") == nil, "W6 Beam vers une pièce absente (Head) retiré")
	local all = fxAttachments(char, "Aura")
	local tagged, ids = true, true
	for _, a in all do
		tagged = tagged and hasTag(a, "CosmeticAura")
		ids = ids and a:GetAttribute("CosmeticId") == "Plasma"
	end
	check(#all == 5 and tagged and ids, "W7 5 copies, marquées CosmeticFx = Aura, CosmeticId = Plasma, taggées CosmeticAura")
	check(cCoeur.Globe:GetAttribute("FullRate") == 12 and cPoing.PoingPlasma:GetAttribute("FullRate") == 6, "W8 FullRate posé sur les émetteurs de l'aura")
	check(not scriptsIn(char), "W9 aucun script dans le perso")

	CosmeticService.Equip(P1, "Hyperspace")
	step(0.1)
	local cTrail = root:FindFirstChild("Trail_CorpsHaut")
	local tr = cTrail and cTrail:FindFirstChild("Distorsion")
	local fHaut = foot:FindFirstChild("Trail_RayonHaut")
	check(tr ~= nil and tr.Attachment0 == cTrail and tr.Attachment1 == root:FindFirstChild("Trail_CorpsBas"), "W10 trail Hyperspace (FX_Trail_Hyperespace) : Trail relié aux copies du HumanoidRootPart")
	check(fHaut ~= nil and fHaut.Rayon.Attachment1 == foot:FindFirstChild("Trail_RayonBas"), "W11 Trail du pied relié aux copies du pied")
	check(root:FindFirstChild("CosmeticTrail") == nil and #fxAttachments(char, "Trail") == 5, "W12 pas de trail V0, 5 copies marquées Trail")
	check(not hasTag(cTrail, "CosmeticAura") and #fxAttachments(char, "Aura") == 5, "W13 trail pas taggé aura, l'aura reste")
	check(CosmeticService.GetAuraMultiplier(P1) == 8 and CosmeticService.GetTrailMultiplier(P1) == 12, "W14 multiplicateurs de Config (a134 : Plasma ×8, Hyperspace ×12)")

	-- VISUAL EFFECTS OFF : émetteurs, lumière, Beam et Trails des copies éteints, puis rallumés.
	P1:SetAttribute("VfxEnabled", false)
	step(0.6)
	check(near(cCoeur.Globe.Rate, 0) and torso.Aura_Lumiere.Lumiere.Enabled == false and beam.Enabled == false, "W15 OFF : émetteurs de l'aura à débit nul, lumière et Beam éteints")
	check(tr.Enabled == false and fHaut.Rayon.Enabled == false and root.Trail_Warp.Distorsion.Enabled == false, "W16 OFF : Trails et émetteur du trail éteints")
	P1:SetAttribute("VfxEnabled", true)
	step(0.6)
	check(near(cCoeur.Globe.Rate, 12) and torso.Aura_Lumiere.Lumiere.Enabled and beam.Enabled and tr.Enabled and fHaut.Rayon.Enabled and root.Trail_Warp.Distorsion.Enabled, "W17 ON : tout rallumé, débit plein")

	-- Changement : Spark n'a pas de modèle ici → repli par texture, copies Plasma retirées.
	CosmeticService.Equip(P1, "Spark")
	step(0.1)
	check(#fxAttachments(char, "Aura") == 0 and #aurasOf(char) == 1 and aurasOf(char)[1]:GetAttribute("CosmeticId") == "Spark", "W18 changement vers une aura sans modèle : copies retirées, effet V0 (repli)")
	check(#fxAttachments(char, "Trail") == 5, "W19 le trail n'est pas touché par le changement d'aura")
	CosmeticService.Equip(P1, "Plasma")
	step(0.1)
	check(#aurasOf(char) == 0 and #fxAttachments(char, "Aura") == 5, "W20 retour à Plasma : V0 retiré, copies reposées une seule fois")
	CosmeticService.Unequip(P1, "Trail")
	check(#fxAttachments(char, "Trail") == 0 and root:FindFirstChild("CosmeticTrail") == nil, "W21 trail retiré : copies retirées")
	CosmeticService.Equip(P1, "Hyperspace")

	-- W23 (2026-11-11, retour de Cantin : le sceau de l'aura Royal sous le sol) : un effet au sol du modèle
	-- (mannequin R15 : bassin à 3,01 studs du sol) garde sa hauteur au-dessus des pieds d'un perso plus petit.
	local roy = new("Model", { Name = "FX_Aura_Royale" })
	local yRoot = new("Part", { Name = "HumanoidRootPart", CFrame = cf(0, 3.01, 0), Size = Vector3.new(2, 2, 1) }, roy)
	new("Part", { Name = "LeftFoot", CFrame = cf(-0.5, 0.3, 0), Size = Vector3.new(1, 0.6, 1) }, roy)
	new("Attachment", { Name = "Aura_Sol", Position = Vector3.new(0, -2.95, 0) }, yRoot)
	new("Attachment", { Name = "Aura_Dos", Position = Vector3.new(0, 0.5, 0.6) }, yRoot)
	roy.Parent = plasma.Parent
	char.Humanoid.HipHeight = 1.8
	CosmeticService.Grant(P1, "Royal")
	CosmeticService.Equip(P1, "Royal")
	step(0.1)
	local rSol, rDos = root:FindFirstChild("Aura_Sol"), root:FindFirstChild("Aura_Dos")
	local expected = 0.06 - (1.8 + root.Size.Y / 2)
	check(rSol ~= nil and math.abs(rSol.Position.Y - expected) < 1e-3 and rDos ~= nil and math.abs(rDos.Position.Y - 0.5) < 1e-3,
		"W23 effet au sol gardé à 0,06 stud au-dessus des pieds d'un perso plus petit (HipHeight 1,8) ; effet du dos inchangé")

	-- Mort : tout est retiré du corps.
	local hum = char.Humanoid
	hum.Health = 0
	hum.Died:Fire()
	step(0.05)
	check(#fxAttachments(char, "Aura") == 0 and #fxAttachments(char, "Trail") == 0, "W22 à la mort : copies d'aura et de trail retirées")
end

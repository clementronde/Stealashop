--!nocheck
-- a96 (vague 29, bot joueur) : compléments du faux Roblox et de la mise en place du banc a29.
--   - Players:CreateHumanoidModelFromDescriptionAsync : un rig R15 simplifié (HumanoidRootPart, UpperTorso,
--     Head, Humanoid, Animator) avec le script Animate de Roblox et son idle (animation par défaut) ;
--     AVATAR_FAIL = true le fait échouer (Studio hors ligne) ;
--   - Animator:LoadAnimation : une piste notée dans IDLE_TRACKS (Play, Looped) ;
--   - BotService dans Server/Services (vrai), chargé par le vrai Loader avec les autres.

AVATAR_CALLS = 0
IDLE_TRACKS = {}
function Methods.CreateHumanoidModelFromDescriptionAsync(_self, description, rigType)
	AVATAR_CALLS += 1
	if AVATAR_FAIL then
		error("HTTP 503 (faux Roblox)")
	end
	assert(description ~= nil and rigType == "Enum.HumanoidRigType.R15", "rig R15 attendu")
	local model = make("Model", { Name = "Player" })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, model)
	make("Part", { Name = "UpperTorso", Size = Vector3.new(2, 1.6, 1), CFrame = CFrame.new(0, 3.2, 0) }, model)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(0, 4.6, 0) }, model)
	local humanoid = make("Humanoid", { Name = "Humanoid", HipHeight = 2 }, model)
	make("Animator", { Name = "Animator" }, humanoid)
	local animate = make("LocalScript", { Name = "Animate" }, model)
	local idle = make("StringValue", { Name = "idle" }, animate)
	make("Animation", { Name = "Animation1", AnimationId = "rbxassetid://507766666" }, idle)
	local walk = make("StringValue", { Name = "walk" }, animate)
	make("Animation", { Name = "WalkAnim", AnimationId = "rbxassetid://507777826" }, walk)
	model.PrimaryPart = root
	return model
end
function Methods.LoadAnimation(self, animation)
	local track = { Animation = animation, Animator = self, Looped = false, Playing = false }
	function track.Play(t)
		t.Playing = true
	end
	function track.Stop(t)
		t.Playing = false
	end
	table.insert(IDLE_TRACKS, track)
	return track
end

moduleScript(SERVICES, "BotService", "server/Services/BotService.luau")

-- Démarre le serveur (setup) et garde BotService.
function startBotServer()
	startServer()
	BotService = serverModule("BotService")
	BotConfig = sharedModule("Config/Bot")
end

-- Boutiques 4 à 6 (même gabarit), à appeler avant startBotServer : loin du hub, l'avant vers −Z.
function makeExtraShops()
	makeShop(4, CFrame.new(0, 0, -150))
	makeShop(5, CFrame.new(110, 0, -150))
	makeShop(6, CFrame.new(220, 0, -150))
end

-- Objets du bot dans sa boutique : modèles DisplayItem du dossier DisplayItems.
function botModels(plot)
	local list = {}
	local folder = plot:FindFirstChild("DisplayItems")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and hasTag(child, "DisplayItem") then
				table.insert(list, child)
			end
		end
	end
	return list
end
function countOf(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end
function signText(plot)
	local label = plot:FindFirstChild("NameSign"):FindFirstChild("Board"):FindFirstChild("SignGui"):FindFirstChild("OwnerName")
	return label.Text
end
function doorMaxHP(plot)
	return plot:FindFirstChild("PlotDoor"):FindFirstChild("Window"):GetAttribute("MaxHP")
end
-- Rien du bot ne reste sur la parcelle (départ propre).
function botLeftClean(plot, label)
	check(plot:GetAttribute("BotName") == nil and plot:GetAttribute("BotIncome") == nil, `{label} : attributs BotName et BotIncome retirés`)
	check(#botModels(plot) == 0 or plot:GetAttribute("OwnerUserId") ~= 0, `{label} : aucun objet du bot laissé`)
	check(plot:FindFirstChild("BotAvatar") == nil, `{label} : avatar du bot retiré`)
	check(not PlotService.IsBotPlot(plot) and not BotService.IsBotPlot(plot) and BotService.GetBotPlot() == nil, `{label} : PlotService et BotService n'y voient plus de bot`)
end

-- a124 (2026-11-14, vague 37 : le bot défend sa boutique, BotService le fait courir) : ajout pur, seulement si
-- le faux Roblox ne les a pas. Humanoid:MoveTo garde la cible (le bot ne bouge pas dans ce banc) ;
-- BasePart:SetNetworkOwner la note.
if Methods.MoveTo == nil then
	function Methods.MoveTo(self, position)
		rawset(self, "_moveTarget", position)
	end
end
if Methods.SetNetworkOwner == nil then
	function Methods.SetNetworkOwner(self, owner)
		rawset(self, "_networkOwner", owner)
	end
end

--!nocheck
-- a251 : Reveal/Unbox monté dans l'arbre du client (après le head du banc a204), modèles et billboards de Clément
-- (outils, objets jetés, effets, BB_UnboxOdds, BB_UnboxWord, BB_UnboxMark, UI_Unbox.EdgeGlow), animations Unbox_*.
moduleScript(CONTROLLERS.Reveal, "Unbox", "client/Controllers/Reveal/Unbox.luau")

-- Outils et objets jetés : ReplicatedStorage/Assets/Unbox.
UNBOX_FOLDER = folder(ASSETS, "Unbox")
function buildTool(name)
	local tool = make("Model", { Name = name }, UNBOX_FOLDER)
	local handle = make("Part", { Name = "Handle", Size = Vector3.new(0.3, 1, 0.3), CFrame = CFrame.new(0, 0, 0) }, tool)
	make("Part", { Name = "Head", Size = Vector3.new(1, 0.5, 0.5), CFrame = CFrame.new(0, 1, 0) }, tool)
	make("Script", { Name = "Bad" }, tool)
	tool.PrimaryPart = handle
	return tool
end
function buildJunk(name)
	local junk = make("Model", { Name = name }, UNBOX_FOLDER)
	junk.PrimaryPart = make("Part", { Name = "Body", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(0, 0, 0) }, junk)
	return junk
end

-- Effets : ReplicatedStorage/Assets/FX/<nom> = Root + Attachments Base et Top, un émetteur par Attachment.
FX_FOLDER_251 = ASSETS:FindFirstChild("FX") or folder(ASSETS, "FX")
function buildFx(name, count, attrs)
	local fx = make("Model", { Name = name }, FX_FOLDER_251)
	local root = make("Part", { Name = "Root", Anchored = true, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0, 0) }, fx)
	fx.PrimaryPart = root
	local base = make("Attachment", { Name = "Base", CFrame = CFrame.new(0, 0, 0) }, root)
	local top = make("Attachment", { Name = "Top", CFrame = CFrame.new(0, 0, 0) }, root)
	local dust = make("ParticleEmitter", { Name = "Dust", Rate = 0 }, base)
	dust:SetAttribute("EmitCount", count)
	local bits = make("ParticleEmitter", { Name = "Bits", Rate = 0 }, top)
	bits:SetAttribute("EmitCount", count + 1)
	bits:SetAttribute("RarityColor", true)
	fx:SetAttribute("Duration", 0.9)
	for key, value in attrs or {} do
		fx:SetAttribute(key, value)
	end
	return fx
end
-- Lancers (depuis l'index `from` de EMITS) d'un émetteur nommé `emitter` d'une copie de l'effet `fx` ; avec `count`,
-- seulement ceux de ce nombre de particules. Le nom de l'effet est noté au lancer (la copie est détruite ensuite).
function Methods.Emit(self, n)
	local model = self:FindFirstAncestorWhichIsA("Model")
	table.insert(EMITS, { emitter = self, n = n, fx = model and model.Name })
end
function emitsOf(fx, emitter, from, count)
	local n = 0
	for i = (from or 0) + 1, #EMITS do
		local e = EMITS[i]
		if e.emitter.Name == emitter and e.fx == fx and (count == nil or e.n == count) then
			n += 1
		end
	end
	return n
end

-- Billboards : ReplicatedStorage/Assets/UI.
function buildBoards()
	local odds = make("BillboardGui", { Name = "BB_UnboxOdds", StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0) }, UI_FOLDER)
	make("TextLabel", { Name = "Odds", Text = "", Visible = true, TextColor3 = Color3.new(1, 1, 1) }, odds)
	make("TextLabel", { Name = "Rarity", Text = "", Visible = true, TextColor3 = Color3.new(1, 1, 1) }, odds)
	make("TextLabel", { Name = "Upgrade", Text = "UPGRADE!", Visible = false }, odds)
	local word = make("BillboardGui", { Name = "BB_UnboxWord", StudsOffsetWorldSpace = Vector3.new(0, 1, 0) }, UI_FOLDER)
	make("TextLabel", { Name = "Word", Text = "", TextTransparency = 0 }, word)
	local mark = make("BillboardGui", { Name = "BB_UnboxMark", StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0) }, UI_FOLDER)
	make("TextLabel", { Name = "Mark", Text = "" }, mark)
end

-- Animations du joueur : ReplicatedStorage/Assets/Animations/Player/<nom> (durée et marqueurs du faux Roblox d'a204).
function buildAnim(name, length, markers)
	local anims = ASSETS:FindFirstChild("Animations") or folder(ASSETS, "Animations")
	local playerFolder = anims:FindFirstChild("Player") or folder(anims, "Player")
	local a = playerFolder:FindFirstChild(name) or make("Animation", { Name = name, AnimationId = "rbxassetid://25" .. tostring(#name) }, playerFolder)
	a:SetAttribute("BenchLength", length)
	a:SetAttribute("BenchMarkers", markers)
	return a
end

-- Copies posées dans Workspace/_RevealFX sous ce nom.
function fxCopies(name)
	local n = 0
	local f = Workspace:FindFirstChild("_RevealFX")
	if f then
		for _, c in f:GetChildren() do
			if c.Name == name then
				n += 1
			end
		end
	end
	return n
end

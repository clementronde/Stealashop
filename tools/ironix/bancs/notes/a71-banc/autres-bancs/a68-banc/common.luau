--!nocheck
-- Commun aux scénarios d'a68 : sons et bulle de Clément, écrans UI_HUD (LeftRail) et UI_Hotbar, vigile.
function buildFeelAssets()
	local sounds = ASSETS:FindFirstChild("Sounds") or folder(ASSETS, "Sounds")
	local chaseFolder = folder(sounds, "Chase")
	local heistFolder = folder(sounds, "Heist")
	SIREN = make("Sound", { Name = "Chase_Siren", Volume = 0.3, SoundId = "rbxassetid://1" }, chaseFolder)
	make("Sound", { Name = "Chase_Whistle", Volume = 0.6, SoundId = "rbxassetid://2" }, chaseFolder)
	make("Sound", { Name = "Guard_Radio", Volume = 0.5, SoundId = "rbxassetid://3" }, chaseFolder)
	make("Sound", { Name = "Heist_Grab", Volume = 0.6, SoundId = "rbxassetid://4" }, heistFolder)
	BB = make("BillboardGui", { Name = "BB_GuardShout", AlwaysOnTop = true, MaxDistance = 150 }, UI_FOLDER)
	local bubble = make("Frame", { Name = "Bubble" }, BB)
	make("TextLabel", { Name = "ShoutLabel", Text = "STOP RIGHT THERE!" }, bubble)
	make("Frame", { Name = "Tail" }, BB)
	make("TextLabel", { Name = "Bang", Text = "!" }, BB)
end
-- Copies jouées (SoundService) dont le nom est `name`.
function sfx(name)
	local out = {}
	for _, child in SoundService:GetChildren() do
		if child:IsA("Sound") and child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end
function buildScreens(player, railVisible, hotbarEnabled, touchVisible)
	local hud = make("ScreenGui", { Name = "UI_HUD" }, player.PlayerGui)
	local rail = make("Frame", { Name = "LeftRail", Visible = railVisible }, hud)
	local hotbar = make("ScreenGui", { Name = "UI_Hotbar", Enabled = hotbarEnabled }, player.PlayerGui)
	-- a71 : colonne de gauche du téléphone (UI_HUD.LeftRailTouch), seulement si touchVisible est donné.
	local touch = if touchVisible ~= nil then make("Frame", { Name = "LeftRailTouch", Visible = touchVisible }, hud) else nil
	return rail, hotbar, touch
end
function buildGuard(player, x)
	local guards = Workspace:FindFirstChild("ActiveGuards") or folder(Workspace, "ActiveGuards")
	local guard = make("Model", { Name = "Guard_Z1" }, guards)
	local root = make("Part", { Name = "HumanoidRootPart", Anchored = true, CFrame = CFrame.new(x, 3, 0) }, guard)
	local head = make("Part", { Name = "Head", Anchored = true, CFrame = CFrame.new(x, 5, 0) }, guard)
	guard.PrimaryPart = root
	guard:SetAttribute("TargetUserId", player.UserId)
	return guard, head
end
function bubbleOf(player)
	return player.PlayerGui:FindFirstChild("BB_GuardShout")
end
function scaleValue(object)
	local s = object and object:FindFirstChildOfClass("UIScale")
	return if s then s.Scale else nil
end
-- a71 : un morceau de la bulle se voit-il ? (Visible et échelle > 0)
function partShown(part)
	if part == nil or not part.Visible then
		return false
	end
	local s = part:FindFirstChildOfClass("UIScale")
	return s == nil or s.Scale > 0
end

--!nocheck
---------------------------------------------------------------- montage a85 (après setup.luau et setup-a60.luau)
-- Vrais modules : Shared, Controllers/UI/Motion, UiFeelController, SkillTreeController et SkillTree/{Fx,Nav}.
-- Net bouchonné : les envois du client vont dans SENT ; le serveur est simulé par les scénarios (ils posent
-- les attributs Skill_<Id> et Cash comme SkillTreeService et DataService).
SENT = {}
SOURCES["shared/Net/Net.luau"] = [==[
local Net = { Client = {} }
setmetatable(Net.Client, {
	__index = function(_, name)
		return {
			Fire = function(_, ...)
				table.insert(SENT, { name = name, args = table.pack(...) })
			end,
			Connect = function()
				return { Disconnect = function() end }
			end,
		}
	end,
})
return Net
]==]
SKILL_MODULE = moduleScript(CONTROLLERS, "SkillTreeController", "client/Controllers/SkillTreeController.luau")
local helpers = folder(CONTROLLERS, "SkillTree")
moduleScript(helpers, "Fx", "client/Controllers/SkillTree/Fx.luau")
moduleScript(helpers, "Nav", "client/Controllers/SkillTree/Nav.luau")
for _, name in { "UI_Deny", "UI_Open", "UI_Close" } do
	new("Sound", { Name = name }, SOUNDS)
end

NEW = new
RICH = true
SkillTreeC = requireModule(ReplicatedStorage.Shared.Config.SkillTree, "client")
ST = UiMotionC.SkillTree

-- Démarrage : attributs du serveur d'abord (`attrs`), puis écrans, puis UiFeelController et SkillTreeController.
function start85(attrs)
	for name, value in attrs or {} do
		P1:SetAttribute(name, value)
	end
	HUD85 = buildHud85(PLAYER_GUI)
	GUI = buildSkillTree(PLAYER_GUI)
	FEEL = requireModule(FEEL_MODULE, "client")
	taskLib.spawn(FEEL.Start)
	SKILL = requireModule(SKILL_MODULE, "client")
	taskLib.spawn(SKILL.Start)
	step(0.1)
	TREE = GUI.Tree
	return SKILL
end

function tile(name)
	return TREE:FindFirstChild(name)
end
function tileEl(name, path)
	local current = tile(name)
	for segment in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(segment, true)
	end
	return current
end
function panelEl(name)
	return GUI.InfoPanel:FindFirstChild(name, true)
end
function shownLayer(name)
	local out = {}
	for _, layer in { "Bought", "Available", "Locked" } do
		if tile(name)[layer].Visible then
			table.insert(out, layer)
		end
	end
	return table.concat(out, ",")
end
function click(button)
	button.Activated:Fire()
	step(1 / 30)
end
function sentOf(remote)
	local out = {}
	for _, entry in SENT do
		if entry.name == remote then
			table.insert(out, entry.args[1])
		end
	end
	return out
end
-- Le UIScale de l'effet sur `object` (SkillTree.ScaleName), ou nil.
function fxScale(object)
	return scaleNamed(object, ST.ScaleName)
end
function zoomScale()
	return scaleNamed(TREE, ST.ZoomScaleName)
end
function centerOf(object)
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

-- Entrées : un objet comme InputObject (UserInputType, Position en Vector3). Les positions données ici sont
-- celles des AbsolutePosition ; l'entrée Roblox (input.Position) est dans ce même repère, même avec
-- IgnoreGuiInset (mesuré en Play le 2026-11-11) ; seul GetMouseLocation ajoute la barre du haut (+ INSET_Y).
local function input(kind, x, y, z)
	return { UserInputType = kind, Position = Vector3.new(x, y, z or 0) }
end
function layer()
	return GUI:FindFirstChild("NavLayer")
end
function mouseDown(x, y)
	layer().InputBegan:Fire(input(Enum.UserInputType.MouseButton1, x, y))
end
function mouseMove(x, y)
	local i = input(Enum.UserInputType.MouseMovement, x, y)
	MOUSE_AT = Vector2.new(x, y + INSET_Y)
	UserInputServiceStub.InputChanged:Fire(i)
	layer().InputChanged:Fire(i)
end
function mouseUp(x, y)
	UserInputServiceStub.InputEnded:Fire(input(Enum.UserInputType.MouseButton1, x, y))
end
function wheel(x, y, notches)
	layer().InputChanged:Fire(input(Enum.UserInputType.MouseWheel, x, y, notches))
end
function tapAt(point)
	mouseDown(point.X, point.Y)
	mouseUp(point.X, point.Y)
	step(1 / 30)
end
function touch(x, y)
	return input(Enum.UserInputType.Touch, x, y)
end
function touchDown(t)
	layer().InputBegan:Fire(t)
end
function touchMove(t, x, y)
	t.Position = Vector3.new(x, y, 0)
	UserInputServiceStub.InputChanged:Fire(t)
end
function touchUp(t)
	UserInputServiceStub.InputEnded:Fire(t)
end
function countNamed(root, name)
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end
function section(title)
	print("\n== " .. title)
end

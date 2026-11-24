--!nocheck
-- Banc a126 (vague 38) : lu après setup.luau du banc a39 (copie a95). Ajoute à l'arbre du client les contrôleurs
-- testés ici (NotifyController, PawnShopController, AdminController ; HudController y est déjà) et les écrans de
-- Clément qu'ils lisent : UI_Toast (Stack.Template), UI_PawnShop (Dialog.Choices, 5 choix), AdminButton dans UI_HUD.

-- ContextActionService (touches 1, 2 et 3 du receleur), absent du faux Roblox d'a39 : ajouté côté client (ajout pur).
CAS_BOUND = {}
do
	local ContextActionStub = {
		BindActionAtPriority = function(_self, name, fn)
			CAS_BOUND[name] = fn
		end,
		BindAction = function(_self, name, fn)
			CAS_BOUND[name] = fn
		end,
		UnbindAction = function(_self, name)
			CAS_BOUND[name] = nil
		end,
	}
	local base = games.client
	games.client = {
		GetService = function(_self, name)
			if name == "ContextActionService" then
				return ContextActionStub
			end
			return base:GetService(name)
		end,
		IsLoaded = function()
			return true
		end,
		Loaded = base.Loaded,
	}
end

for _, name in { "NotifyController", "PawnShopController", "AdminController" } do
	if SOURCES[`client/Controllers/{name}.luau`] then
		moduleScript(CONTROLLERS, name, `client/Controllers/{name}.luau`)
	end
end

-- UI_Toast (relevé du 2026-11-11, wave24-studio.md) : Stack (UIListLayout), Template TextLabel caché.
function buildToast(parent)
	local gui = make("ScreenGui", { Name = "UI_Toast", Enabled = false, ResetOnSpawn = false })
	local stack = make("Frame", { Name = "Stack" }, gui)
	make("UIListLayout", { Name = "UIListLayout" }, stack)
	make("TextLabel", { Name = "Template", Text = "Crown equipped!", Visible = false }, stack)
	gui.Parent = parent
	return gui
end
function toastCopies(gui)
	local out = {}
	for _, child in gui:FindFirstChild("Stack", true):GetChildren() do
		if string.sub(child.Name, 1, 6) == "Toast_" then
			table.insert(out, child)
		end
	end
	return out
end

-- UI_PawnShop (relevé du 2026-11-12, wave29-studio.md) : Dialog, Dialog.Choices et ses 5 choix (KeyLabel,
-- ChoiceLabel, Price pour les choix à prix).
function buildPawnShop(parent)
	local gui = make("ScreenGui", { Name = "UI_PawnShop", Enabled = false, ResetOnSpawn = false })
	local dialog = make("Frame", { Name = "Dialog" }, gui)
	local choices = make("Frame", { Name = "Choices" }, dialog)
	for i, name in { "SellHeldButton", "SellAllButton", "LeaveButton", "DealButton", "NoDealButton" } do
		local button = make("TextButton", { Name = name, Text = "", Visible = i <= 3 }, choices)
		make("TextLabel", { Name = "KeyLabel", Text = tostring(i) }, button)
		make("TextLabel", { Name = "ChoiceLabel", Text = name }, button)
		if name ~= "LeaveButton" and name ~= "NoDealButton" then
			make("TextLabel", { Name = "Price", Text = "$0" }, button)
		end
	end
	gui.Parent = parent
	return gui
end

-- AdminButton de Clément (caché par lui, montré par AdminController aux admins), dans le HUD.
function addAdminButton(hud)
	local button = make("TextButton", { Name = "AdminButton", Text = "", Visible = false }, hud)
	make("TextLabel", { Name = "AdminLabel", Text = "ADMIN" }, button)
	return button
end

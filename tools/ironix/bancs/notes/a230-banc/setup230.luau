---------------------------------------------------------------- montage a230 (après setup190.luau)
-- Faux Roblox : CFrame.RightVector et UpVector (colonnes 1 et 2 de la matrice ; LookVector = -colonne 3 dans stubs).
do
	local mt = getmetatable(CFrame.identity)
	local old = mt.__index
	mt.__index = function(c, k)
		if k == "RightVector" then
			return Vector3.new(c.r[1], c.r[4], c.r[7])
		elseif k == "UpVector" then
			return Vector3.new(c.r[2], c.r[5], c.r[8])
		end
		return old(c, k)
	end
end
-- Faux UserInputService pilotable (game:GetService, des deux côtés) : PC par défaut.
INPUTS = { TouchEnabled = false, KeyboardEnabled = true }
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "UserInputService" then
				return INPUTS
			end
			return old:GetService(name)
		end,
	}
end
-- InventoryController bouchonné : état pilotable, OnChanged.
SOURCES["stub/InventoryController"] = [==[
local I = { state = { Items = {} }, listeners = {} }
function I.GetInventory()
	return I.state
end
function I.OnChanged(fn)
	table.insert(I.listeners, fn)
	return function() end
end
function I.Fire()
	for _, fn in I.listeners do
		fn()
	end
end
return I
]==]
INV_MODULE = moduleScript(CONTROLLERS, "InventoryController", "stub/InventoryController")
HELD_MODULE = moduleScript(CONTROLLERS, "HeldIncomeController", "client/Controllers/HeldIncomeController.luau")

-- BottomRow de Clément (refonte_ui_hud_v2/v3) dans `hud` : FriendBoost visible, les trois autres cachés ; Timer (nom proposé)
-- sous CashBoost si `timer`. Le HUD est sorti puis remis dans PlayerGui pour être rebranché.
function addBottomRow(hud, timer)
	hud.Parent = nil
	local bottomLeft = new("Frame", { Name = "BottomLeft" }, hud)
	local row = new("Frame", { Name = "BottomRow" }, bottomLeft)
	for _, spec in { { "FriendBoost", "+0%", true }, { "VipBoost", "+10%", false }, { "CashBoost", "x2", false }, { "TrainingBoost", "x2", false } } do
		local pill = new("Frame", { Name = spec[1], Visible = spec[3] }, row)
		new("ImageLabel", { Name = "Icon" }, pill)
		new("TextLabel", { Name = "Amount", Text = spec[2] }, pill)
	end
	if timer then
		new("TextLabel", { Name = "Timer", Text = "9:99", Visible = true }, el(row, "CashBoost"))
	end
	hud.Parent = PLAYER_GUI
	return row
end

-- Shared/RarityHalo (nom de la pièce du halo, requis par HeldIncomeController) lit NumberRange au chargement.
if NumberRange == nil then
	NumberRange = {
		new = function(min, max)
			return { Min = min, Max = max or min }
		end,
	}
end

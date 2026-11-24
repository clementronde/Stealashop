--!nocheck
-- Scénario « panel » (a185, L-169 Q6) : BB_ShopInfo de Clément (ReplicatedStorage/Assets/UI) copié par PvPController ;
-- HP dans HPLine (avec HPIcon), Status en pastille (cadre + texte, le cas le plus dur) cachée quand il n'y a rien à dire.
local assets = ReplicatedStorage:FindFirstChild("Assets") or folder(ReplicatedStorage, "Assets")
local ui = assets:FindFirstChild("UI") or folder(assets, "UI")
local bb = make("BillboardGui", { Name = "BB_ShopInfo", Size = UDim2.fromScale(8, 4.4) }, ui)
local panel = make("Frame", { Name = "Panel" }, bb)
make("TextLabel", { Name = "OwnerName", Text = "Alice's Shop" }, panel)
make("TextLabel", { Name = "Income", Text = "+$0/s" }, panel)
local hpLine = make("Frame", { Name = "HPLine" }, panel)
make("ImageLabel", { Name = "HPIcon" }, hpLine)
make("TextLabel", { Name = "HP", Text = "7/40" }, hpLine)
local pill = make("Frame", { Name = "Status", Visible = true }, panel)
make("TextLabel", { Name = "Label", Text = "LOCKED 23s" }, pill)

startSkills()
local function owner(name)
	local data = newProfile()
	addItem(data, name .. "-soda", "Z1_CanetteDeSoda", 1)
	return join(name, data)
end
local ada = owner("Ada")
local bob = join("Bob", newProfile())
advance(1.2)
startClient(bob)
local shop = shopOf(ada)
local S = refsOfShop(shop)
moveTo(bob, S.outside + S.front * -1)
advance(0.6)

local function gui()
	return bob.PlayerGui:FindFirstChild("ShopInfo_" .. shop.Name)
end
local function pillState()
	local g = gui()
	local status = if g then g:FindFirstChild("Status", true) else nil
	local label = if status then status:FindFirstChild("Label") else nil
	return status and status.Visible, label and label.Text
end

section("copie de BB_ShopInfo")
local g = gui()
check(g ~= nil and g:FindFirstChild("Panel") ~= nil, "le panneau est la copie de BB_ShopInfo (Panel présent)")
check(g ~= nil and g.Size == UDim2.fromScale(8, 4.4), "taille de Clément gardée (8 × 4,4)")
local hp = if g then g:FindFirstChild("HP", true) else nil
check(hp ~= nil and hp.Text == "40/40", `HP dans HPLine : « {hp and hp.Text} »`)
local on = if g then g:FindFirstChild("OwnerName", true) else nil
check(on ~= nil and on.Text == "Ada's Shop", `OwnerName : « {on and on.Text} »`)
local visible, text = pillState()
check(visible == false, `Status caché quand il n'y a rien à dire (Visible = {tostring(visible)}, « {text} »)`)

section("LOCKED")
shop:SetAttribute("LockedUntil", Workspace:GetServerTimeNow() + 23)
advance(0.4)
visible, text = pillState()
check(visible == true and text ~= nil and string.match(text, "^LOCKED %d+s$") ~= nil, `« {text} » montré`)
shop:SetAttribute("LockedUntil", nil)
advance(0.4)
visible = pillState()
check(visible == false, "verrou levé : Status caché")

section("OPEN")
shop:SetAttribute("StealOpen", true)
advance(0.4)
visible, text = pillState()
check(visible == true and text == "OPEN", `« {text} » montré`)
shop:SetAttribute("StealOpen", nil)
advance(0.4)

section("ROB AGAIN IN")
local key = `RobCooldown_{shop:GetAttribute("PlotIndex")}`
bob:SetAttribute(key, Workspace:GetServerTimeNow() + 42)
advance(0.4)
visible, text = pillState()
check(visible == true and text ~= nil and string.match(text, "^ROB AGAIN IN %d+s$") ~= nil, `« {text} » montré`)
bob:SetAttribute(key, nil)
advance(0.4)
visible = pillState()
check(visible == false, "interdiction finie : Status caché de nouveau")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario panel")

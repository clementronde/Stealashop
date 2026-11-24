--!nocheck
-- a294 (21/11, client) : RevealController + Reveal/Unbox sur un RevealStarted de la caisse exclusive (mise en place du
-- banc a287 : a204, a259). Le plan est celui que tire le serveur (UnboxPlan.draw : rareté de l'objet, colis montré
-- Épique, 0 amélioration, cote = Formulas.UnboxOdds(chance)) ; ShopId ExclusiveCrate (aucun magasin) : le colis sort
-- devant l'acheteur (RevealController.frameOf). Un objet par rareté de la caisse.
--   K1 la scène part : colis devant Alice, autant de coups que le plan, cote de départ 1 IN 2
--   K2 elle se joue jusqu'au bout : Reveal, cote finale = celle du plan, jamais vers le bas, BB_Reveal à son nom
--   K3 RevealDone envoyé une fois au serveur avec l'id de la caisse ; RevealEnded la ferme
local Plan = sharedModule("UnboxPlan", "client")
local Cfg = sharedModule("Config/Unbox", "client")
local Monetization = sharedModule("Config/Monetization", "client")
local Items = sharedModule("Config/Items", "client")
local Formulas = sharedModule("Config/Formulas", "client")
local New = Cfg.New
local Crate = Monetization.Crate
local Reveal = Crate.Reveal

local alice = newPlayer("Alice")
local START = Vector3.new(0, 3, 40)
local function spawn(player, position)
	local character = spawnCharacter(player, position)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.HipHeight = 2
	make("Animator", { Name = "Animator" }, humanoid)
	local hand = make("Part", { Name = "RightHand", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position + Vector3.new(1, 0, 0)), CanCollide = false }, character)
	make("Attachment", { Name = "RightGripAttachment", CFrame = CFrame.new(0, -0.2, 0) }, hand)
	return character
end
spawn(alice, START)
make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
make("ScreenGui", { Name = "UI_Escape", Enabled = true }, alice.PlayerGui)
local unboxScreen = make("ScreenGui", { Name = "UI_Unbox", Enabled = false }, alice.PlayerGui)
make("ImageLabel", { Name = "EdgeGlow", ImageTransparency = 1, ImageColor3 = Color3.new(1, 1, 1) }, unboxScreen)
Workspace.CurrentCamera = CAMERA
CAMERA.FieldOfView = 70
local function homeCamera()
	CAMERA.CameraType = Enum.CameraType.Custom
	CAMERA.CameraSubject = alice.Character:FindFirstChildOfClass("Humanoid")
	CAMERA.CFrame = CFrame.lookAt(START + Vector3.new(0, 5, 25), START)
end
homeCamera()
dropRig()
startClient(alice)
local RC = clientModule("RevealController")

local function scene(id)
	for _, s in RC.GetState().Scenes do
		if s.Id == id then
			return s
		end
	end
	return nil
end
local function unbox(id)
	local s = scene(id)
	return s and s.Unbox
end
local function fired(id, marker)
	local s = scene(id)
	return s ~= nil and table.find(s.Fired, marker) ~= nil
end
local function pivotOf(inst)
	if inst == nil then
		return nil
	end
	local ok, cf = pcall(function()
		return inst:GetPivot()
	end)
	return if ok then cf else nil
end
local seed = 0
local function pick(n)
	seed += 1
	return 1 + (seed * 7) % n
end

for index, itemId in Crate.Items do
	local def = Items.ById[itemId]
	local chance = Crate.Odds[index]
	local odds = Formulas.UnboxOdds(chance / 100)
	local plan = Plan.draw(def.Rarity, pick, Reveal.StartRarity, 0, odds)
	local parsed = Plan.parse(plan)
	local id = `Crate{index}`
	local label = `{itemId} ({def.Rarity}, {chance} %)`
	section("K " .. label)
	homeCamera()
	moveTo(alice, START)
	flush()
	local root = alice.Character.HumanoidRootPart
	local front = (root.CFrame * CFrame.new(0, -3, -4)).Position
	local doneBefore = RC.GetState().DoneSent
	NET.Server.RevealStarted:FireAll(alice, Reveal.ShopId, Reveal.SlotName, itemId, def.Rarity, "", 10, 1, "Small", id, plan)
	flush()
	local s = scene(id)
	local u = unbox(id)
	check(s ~= nil and s.Opener == true and u ~= nil, `K1 {label} : scène d'ouverture jouée, Alice ouvreuse`)
	check(u ~= nil and parsed ~= nil and #u.Moves == #parsed.Steps and #parsed.Steps == New.ActionsByRarity[def.Rarity], `K1 {label} : {u and #u.Moves} coups (plan {parsed and #parsed.Steps}, attendu {New.ActionsByRarity[def.Rarity]})`)
	check(u ~= nil and u.OddsText == "1 IN 2" and u.OddsVisible, `K1 {label} : cote de départ « {u and u.OddsText} »`)
	local box = pivotOf(u and u.Box)
	local base = pivotOf(u and u.Base)
	local at = (box or base)
	local dist = if at then (Vector3.new(at.Position.X, 0, at.Position.Z) - Vector3.new(front.X, 0, front.Z)).Magnitude else math.huge
	check(dist < 3, string.format("K1 %s : colis devant Alice (à %.1f studs du point devant elle)", label, dist))
	local values = {}
	local start = now()
	while not fired(id, "Reveal") and now() - start < 40 do
		advance(1 / 30)
		local v = unbox(id)
		if v and v.Odds then
			table.insert(values, v.Odds)
		end
	end
	check(fired(id, "Reveal"), `K2 {label} : objet révélé ({string.format("%.1f", now() - start)} s)`)
	for _ = 1, math.ceil((New.OddsRoll + 0.1) * 30) do
		advance(1 / 30)
	end
	u = unbox(id)
	local expected = Plan.oddsText(odds)
	check(u ~= nil and u.OddsText == expected, `K2 {label} : cote finale « {u and u.OddsText} » (attendu « {expected} »)`)
	local down = false
	for i = 2, #values do
		if values[i] < values[i - 1] - 1e-9 then
			down = true
		end
	end
	check(not down and #values > 0, `K2 {label} : la cote ne redescend jamais ({#values} images)`)
	local board = s and scene(id).Board
	local lines = board and (board:FindFirstChild("Lines") or board)
	local nameLabel = lines and lines:FindFirstChild("ItemName")
	check(nameLabel == nil or nameLabel.Text == def.DisplayName, `K2 {label} : BB_Reveal.ItemName « {nameLabel and nameLabel.Text} »`)
	local t0 = now()
	while RC.GetState().DoneSent == doneBefore and now() - t0 < 15 do
		advance(1 / 30)
	end
	check(RC.GetState().DoneSent == doneBefore + 1, `K3 {label} : RevealDone envoyé une fois`)
	local sent = serverCalls and serverCalls("RevealDone") or {}
	local last = sent[#sent]
	check(last ~= nil and last.args[1] == id, `K3 {label} : RevealDone({last and last.args[1]}) au serveur`)
	NET.Server.RevealEnded:FireAll(id)
	flush()
	advance(0.5)
	check(scene(id) == nil or scene(id).Stage ~= "Unbox", `K3 {label} : RevealEnded la ferme`)
end
summary("scénario client")

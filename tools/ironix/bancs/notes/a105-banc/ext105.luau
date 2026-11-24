--!nocheck
-- Mise en place du banc a105 (vague 31, L-112 : base de l'ouverture sur le rayon), après setup.luau d'a51 :
--   - CarryService du banc complété : StartCarry (comme Give, renvoie true) et ReportAnomaly (Fail « Anomaly »),
--     pour le vrai PvPService ;
--   - WindowService du banc : CanBeHit, OnBroken, OnRebuilt, GetWindowId (« Plot_<PlotIndex> »), IsBroken
--     (BROKEN) ; breakDoor(owner, breaker) appelle les écouteurs OnBroken comme une porte cassée ;
--   - vrai PvPService à la place du bouchon d'a51 ; une DepositZone dans chaque boutique (dépôt du voleur) ;
--   - aides : npcItem, bringItem, placeItemAt, floorItemOf, invItem.

SOURCES["stub/CarryService"] = [==[
local CarryService = {}
local carrying = {}
local started, ended = {}, {}
function CarryService.IsCarrying(player) return carrying[player] ~= nil end
function CarryService.GetPayload(player) return carrying[player] end
local function finish(player, result, reason)
	local payload = carrying[player]
	if payload == nil then
		return nil
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	table.insert(CARRY_ENDS, { player = player, payload = payload, result = result, reason = reason })
	for _, fn in table.clone(ended) do
		task.spawn(fn, player, payload, result, reason)
	end
	return payload
end
function CarryService.Consume(player, reason)
	return finish(player, "Consumed", reason or "Consumed")
end
function CarryService.Fail(player, reason)
	return finish(player, "Failed", reason) ~= nil
end
function CarryService.ReportAnomaly(player, _why)
	return finish(player, "Failed", "Anomaly") ~= nil
end
function CarryService.OnCarryStarted(fn)
	table.insert(started, fn)
	return function() end
end
function CarryService.OnCarryEnded(fn)
	table.insert(ended, fn)
	return function() end
end
function CarryService.Give(player, payload)
	carrying[player] = payload
	player:SetAttribute("Carrying", if payload then payload.Rarity else nil)
	if payload then
		for _, fn in table.clone(started) do
			task.spawn(fn, player, payload)
		end
	end
end
function CarryService.StartCarry(player, payload)
	if carrying[player] ~= nil then
		return false
	end
	CarryService.Give(player, payload)
	return true
end
return CarryService
]==]

SOURCES["stub/WindowService"] = [==[
local WindowService = { Priority = 100 }
local brokenListeners, rebuiltListeners = {}, {}
function WindowService.CanBeHit(_player, _windowId) return true end
function WindowService.OnBroken(fn) table.insert(brokenListeners, fn) return function() end end
function WindowService.OnRebuilt(fn) table.insert(rebuiltListeners, fn) return function() end end
function WindowService.GetWindowId(plot) return "Plot_" .. tostring(plot:GetAttribute("PlotIndex")) end
function WindowService.IsBroken(windowId) return BROKEN[windowId] == true end
function WindowService.AddRebuildGate(_gate) end -- a112 (vague 33) : point d'attente de PvPService, sans effet ici
function WindowService.FireBroken(info)
	BROKEN[info.WindowId] = true
	for _, fn in table.clone(brokenListeners) do
		fn(info)
	end
end
return WindowService
]==]
BROKEN = {}

do
	local stub = SERVICES:FindFirstChild("PvPService")
	if stub then
		stub:Destroy()
	end
	moduleScript(SERVICES, "PvPService", "server/Services/PvPService.luau")
	moduleScript(SERVICES, "WindowService", "stub/WindowService")
end

-- DepositZone (contrat 10.4) de chaque boutique, au fond, côté local +Z (dans Bounds).
for _, entry in SHOPS do
	local origin = entry.S.origin
	make("Part", { Name = "DepositZone", Anchored = true, CFrame = origin * CFrame.new(20, 0.5, 34), Size = Vector3.new(8, 1, 6), CanCollide = false, CanQuery = false }, entry.model)
	entry.S.deposit = origin * Vector3.new(20, 3, 34)
end

function npcItem(itemId, rarity, zone, mutation)
	return { Kind = "NPCItem", ItemId = itemId, Rarity = rarity, Zone = zone or 1, StoreId = "Store_1", SlotId = "Store_1/01", Mutation = mutation, Luck = 1 }
end

-- Le joueur soulève un objet sorti d'un colis dans le couloir, puis rentre dans la zone safe : uid du nouvel
-- objet rangé (nil : pas rangé).
function bringItem(player, itemId, rarity, zone, mutation)
	moveTo(player, CORRIDOR)
	advance(0.05)
	local before = {}
	for uid in dataOf(player).Items do
		before[uid] = true
	end
	CarryService.Give(player, npcItem(itemId, rarity, zone, mutation))
	advance(0.3)
	moveTo(player, refsOfShop(shopOf(player)).center)
	advance(0.6)
	for uid in dataOf(player).Items do
		if not before[uid] then
			return uid
		end
	end
	return nil
end

-- Pose l'objet `uid` (sous antivol, inventaire) au point local (lx, lz) de sa boutique ; renvoie l'entrée du profil.
function placeItemAt(player, uid, lx, lz)
	local point = floorPoint(player, lx, lz)
	standNear(player, point)
	advance(0.3)
	fireAs(player, "PlaceBox", uid, point)
	flush()
	return dataOf(player).Items[uid]
end

function floorItemOf(player, uid)
	local plot = shopOf(player)
	if plot == nil then
		return nil
	end
	for _, child in plot:GetChildren() do
		if child.Name == "FloorItem" and child:GetAttribute("ItemUid") == uid then
			return child
		end
	end
	return nil
end

function breakDoor(owner, breaker)
	local plot = shopOf(owner)
	local WindowService = serverModule("WindowService")
	WindowService.FireBroken({ Kind = "Plot", Model = plot, WindowId = "Plot_" .. tostring(plot:GetAttribute("PlotIndex")), Breaker = breaker })
	flush()
end

-- Délai d'antivol d'une rareté (Config/ShelfOpen).
function antiTheftOf(rarityId)
	return sharedModule("Config/ShelfOpen").AntiTheft[rarityId]
end

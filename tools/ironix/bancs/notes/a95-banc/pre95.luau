---------------------------------------------------------------- a95 : receleur (modules et stand)
-- Les vrais InventoryService et PawnShopService ajoutés à l'arbre avant le démarrage ; stand du receleur dans le hub
-- (relevé wave29-studio : ENV_Hub_PawnStall taggé PawnShop, Vendor_Pawn avec Head, ShopPad), et sa copie de
-- présentation dans _SHOWROOM_CLEMENT (à ignorer).
moduleScript(SERVICES, "InventoryService", "server/Services/InventoryService.luau")
moduleScript(SERVICES, "PawnShopService", "server/Services/PawnShopService.luau")

local function makeStall(parent, origin)
	local stall = make("Model", { Name = "ENV_Hub_PawnStall" }, parent)
	make("Part", { Name = "Counter", Anchored = true, Size = Vector3.new(8, 3, 2), CFrame = CFrame.new(origin + Vector3.new(0, 1.5, -4)) }, stall)
	local pad = make("Part", { Name = "ShopPad", Anchored = true, Size = Vector3.new(6, 0.2, 6), CFrame = CFrame.new(origin) }, stall)
	local vendor = make("Model", { Name = "Vendor_Pawn" }, stall)
	make("Part", { Name = "Head", Anchored = true, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(origin + Vector3.new(0, 5, -6)) }, vendor)
	CollectionService:AddTag(stall, "PawnShop")
	return stall, pad
end
STALL, PAD = makeStall(folder(HUB, "Stalls"), Vector3.new(-40, 0, -120))
SHOWROOM_STALL, SHOWROOM_PAD = makeStall(folder(Workspace, "_SHOWROOM_CLEMENT"), Vector3.new(250, 0, 250))

function onPad(player, pad)
	moveTo(player, (pad or PAD).Position + Vector3.new(0, 3, 0))
	advance(0.05)
end
function offers(player)
	return remotes("PawnOffer", function(e)
		return e.to == player
	end)
end
function lastOffer(player)
	local list = offers(player)
	local e = list[#list]
	return if e then e.args else nil
end
function solds(player)
	return remotes("PawnSold", function(e)
		return e.to == player
	end)
end
function lastSold(player)
	local list = solds(player)
	local e = list[#list]
	return if e then e.args else nil
end

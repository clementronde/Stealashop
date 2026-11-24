--!nocheck
-- Mise en place du banc a142 (2026-11-14, objet de l'inventaire en main), après celles d'a118 (sans setup118) :
--   - vrai HeldItemService dans les services (absent des listes des autres bancs) ;
--   - modèle ITM_Z3_Smartphone de 3 pièces (Root invisible au pivot, Body, Screen) dans Assets/Items ;
--   - aides : heldTool, itemTools, boxOf (boîte sans halo ni poignée, dans le repère d'un CFrame), sizesOf
--     (tailles des pièces, triées), displayModelOf, snapshot (Items, Display et argent du profil, en texte), holdAs.
moduleScript(SERVICES, "HeldItemService", "server/Services/HeldItemService.luau")

do
	local items = ASSETS:FindFirstChild("Items") or folder(ASSETS, "Items")
	local model = make("Model", { Name = "ITM_Z3_Smartphone" })
	local root = make("Part", { Name = "Root", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 0.1, 0) }, model)
	make("Part", { Name = "Body", Anchored = true, Size = Vector3.new(0.9, 1.6, 0.15), CFrame = CFrame.new(0, 0.8, 0) }, model)
	make("Part", { Name = "Screen", Anchored = true, Size = Vector3.new(0.8, 1.4, 0.05), CFrame = CFrame.new(0, 0.85, -0.09) }, model)
	model.PrimaryPart = root
	root.PivotOffset = CFrame.new(0, -0.1, 0) -- pivot en bas au centre (10.1)
	model.Parent = items
end

function heldTool(player)
	local character = player.Character
	if character == nil then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("HeldItemUid") ~= nil then
			return child
		end
	end
	return nil
end

-- Tous les Tools d'objet tenu qui existent encore (personnage, Backpack, Workspace).
function itemTools(player)
	local list = {}
	for _, container in { player.Character, player:FindFirstChild("Backpack"), Workspace } do
		if container then
			for _, d in container:GetDescendants() do
				if d:IsA("Tool") and d:GetAttribute("HeldItemUid") ~= nil and not isDestroyed(d) and not table.find(list, d) then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

local function counted(part)
	return part.Name ~= "RarityHalo" and part.Name ~= "Handle"
end

-- Boîte des pièces (sans halo ni poignée), dans le repère `frame` : centre, taille.
function boxOf(model, frame)
	local lo, hi
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and counted(d) then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = frame:PointToObjectSpace(d.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						lo = if lo then Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z)) else q
						hi = if hi then Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) else q
					end
				end
			end
		end
	end
	return (lo + hi) / 2, hi - lo
end

function sizesOf(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and counted(d) then
			table.insert(list, string.format("%s=%.3f,%.3f,%.3f", d.Name, d.Size.X, d.Size.Y, d.Size.Z))
		end
	end
	table.sort(list)
	return table.concat(list, ";")
end

function displayModelOf(player, uid)
	local plot = shopOf(player)
	for _, d in plot:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("ItemUid") == uid and string.sub(d.Name, 1, 12) == "DisplayItem_" then
			return d
		end
	end
	return nil
end

function snapshot(player)
	local data = dataOf(player)
	local items, display = {}, {}
	for uid, entry in data.Items do
		table.insert(items, uid .. "=" .. tostring(entry.Id))
	end
	for slot, uid in data.Display do
		table.insert(display, slot .. "=" .. uid)
	end
	table.sort(items)
	table.sort(display)
	return table.concat(items, ",") .. " | " .. table.concat(display, ",") .. " | " .. tostring(data.Cash)
end

function holdAs(player, uid)
	fireAs(player, "HoldItem", uid)
	flush()
	advance(0.05)
end

-- Aperçu de tous les objets exposés (catalogue actif), une rangée par zone, dans Workspace/_PREVIEW_OBJETS.
-- Demande de Clément (26/11) : « je veux les voir dans Roblox Studio ». Dossier de travail (préfixe _), jamais lu
-- par le jeu. Copies des modèles de ReplicatedStorage/Assets/Items, à taille réelle, posées loin de la map ; une
-- étiquette au-dessus de chacun (nom affiché, rareté à sa couleur). Relançable : l'ancien aperçu est remplacé.
-- À coller dans la barre de commande, en Edit. Pour y aller : sélectionner _PREVIEW_OBJETS dans l'Explorer, touche F.

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local ORIGIN = Vector3.new(0, 50, -2300) -- hors de la map (elle s'arrête vers z = -1 680)
local ROW_GAP = 7 -- écart entre deux rangées (studs)
local ITEM_GAP = 3 -- écart entre deux objets d'une rangée (studs)
local ROWS = { "Zone_1", "Zone_2", "Zone_3", "Zone_4", "Zone_5", "Zone_6", "Secret", "Exclusive" }

local okItems, Items = pcall(require, RS.Shared.Config.Items)
local okRar, Rarities = pcall(require, RS.Shared.Config.Rarities)

local function info(itemId: string)
	local item = okItems and Items.ById and Items.ById[itemId]
	local rarity = item and item.Rarity or "?"
	local r = okRar and Rarities.ById[rarity]
	return {
		name = item and item.DisplayName or itemId,
		rarity = r and r.DisplayName or rarity,
		order = r and r.Order or 99,
		color = r and r.Color or Color3.new(1, 1, 1),
	}
end

local old = workspace:FindFirstChild("_PREVIEW_OBJETS")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "_PREVIEW_OBJETS"

local function label(parent: Instance, adornee: BasePart, text: string, color: Color3, big: boolean)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Adornee = adornee
	bb.Size = big and UDim2.fromScale(14, 3) or UDim2.fromScale(5, 2)
	bb.StudsOffsetWorldSpace = Vector3.new(0, big and 2 or 1.2, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
end

local counts = {}
for rowIndex, zoneName in ROWS do
	local src = RS.Assets.Items:FindFirstChild(zoneName)
	if not src then
		continue
	end
	local list = {}
	for _, d in src:GetDescendants() do
		if d:IsA("Model") and d.Name:sub(1, 4) == "ITM_" then
			local id = d:GetAttribute("ItemId") or d.Name:sub(5)
			table.insert(list, { model = d, id = id, info = info(id) })
		end
	end
	table.sort(list, function(a, b)
		if a.info.order ~= b.info.order then
			return a.info.order < b.info.order
		end
		return a.id < b.id
	end)
	table.insert(counts, `{zoneName} : {#list}`)

	local row = Instance.new("Model")
	row.Name = string.format("%02d_%s", rowIndex, zoneName)
	row.Parent = root
	local z = ORIGIN.Z - (rowIndex - 1) * ROW_GAP
	local x = ORIGIN.X

	-- Repère de taille d'un perso R15 (environ 5 studs) en tête de rangée.
	local ref = Instance.new("Part")
	ref.Name = "Repere_5_studs"
	ref.Anchored = true
	ref.CanCollide = false
	ref.Size = Vector3.new(1, 5, 1)
	ref.Color = Color3.fromRGB(120, 120, 120)
	ref.Material = Enum.Material.SmoothPlastic
	ref.CFrame = CFrame.new(x - 4, ORIGIN.Y + 2.5, z)
	ref.Parent = row
	label(row, ref, `{(zoneName:gsub("_", " "))} ({#list})`, Color3.new(1, 1, 1), true)

	for _, e in list do
		local c = e.model:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
			if d.Name:sub(1, 4) == "ITM_" then
				d.Name = "PREV_" .. d.Name:sub(5) -- la pièce de maillage porte aussi le nom ITM_
			end
			for _, tag in CS:GetTags(d) do
				CS:RemoveTag(d, tag)
			end
		end
		c:SetAttribute("ItemId", nil)
		c.Name = "PREV_" .. e.id -- pas ITM_ : sinon le ContractChecker compte chaque copie
		local _, size = c:GetBoundingBox()
		local w = math.max(size.X, size.Z)
		x += w / 2
		c:PivotTo(CFrame.new(x, ORIGIN.Y, z))
		local bcf, bsize = c:GetBoundingBox()
		local bottom = bcf.Position.Y - bsize.Y / 2
		c:PivotTo(c:GetPivot() + Vector3.new(0, ORIGIN.Y - bottom, 0))
		c.Parent = row

		local anchor = Instance.new("Part")
		anchor.Name = "LabelAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(x, ORIGIN.Y + bsize.Y, z)
		anchor.Parent = c
		label(c, anchor, `{e.info.name}\n{e.info.rarity}`, e.info.color, false)
		x += w / 2 + ITEM_GAP
	end

	local floor = Instance.new("Part")
	floor.Name = "Sol"
	floor.Anchored = true
	floor.CanCollide = false
	floor.Size = Vector3.new(x - ORIGIN.X + 8, 0.4, ROW_GAP - 2)
	floor.CFrame = CFrame.new((ORIGIN.X - 8 + x) / 2, ORIGIN.Y - 0.2, z)
	floor.Color = Color3.fromRGB(45, 45, 55)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = row
end

root.Parent = workspace
return table.concat(counts, ", ")

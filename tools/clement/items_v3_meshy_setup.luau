--!nocheck
-- Catalogue d'objets v3 (2026-11-24) : range les objets faits avec Meshy (45 : 3 de l'essai + 42) une fois
-- importés par zone (FBX V3_<Zone>_Objets.fbx de StealAShop-Art/Items/V3_Meshy/FBX_Zones, Importateur 3D).
-- À lancer en Edit. Cherche dans Workspace les modèles importés V3_*_Objets (ou un dossier _INBOX_CLEMENT/V3_Meshy),
-- puis pour chaque ITM_<ItemId> :
--   - maillage renommé ITM_<ItemId> (comme le lot Meshy), ancré, sans collision ni requête ni toucher, Box, Massless ;
--   - pièce Root invisible à la taille de l'objet = PrimaryPart, pivot en bas au centre, face avant vers la rue (-Z) ;
--   - attribut ItemId = nom sans ITM_ ; rangé dans ReplicatedStorage/Assets/Items (un nom déjà rangé est remplacé).
-- Rejouable. Ne crée aucun script.

local Items = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Items")

local sources = {}
for _, inst in workspace:GetChildren() do
	if inst.Name:match("^V3_.+_Objets$") then table.insert(sources, inst) end
end
local inbox = workspace:FindFirstChild("_INBOX_CLEMENT")
local v3 = inbox and inbox:FindFirstChild("V3_Meshy")
if v3 then table.insert(sources, v3) end

local done, problems = {}, {}
for _, src in sources do
	for _, model in src:GetDescendants() do
		if not (model:IsA("Model") and model.Name:match("^ITM_[%w_]+")) then continue end
		-- Blender ajoute « .001 » au nom de l'Empty (le maillage portait le même nom à sa création)
		model.Name = model.Name:gsub("%.%d+$", "")
		local name = model.Name
		-- le FBX arrive en centimètres : 1 unité Blender = 1 cm = 1 stud, soit 100 fois trop grand. On réduit les
		-- maillages eux-mêmes, pas le modèle : DisplayService fait Model:ScaleTo(<valeur absolue>), un modèle laissé
		-- à GetScale() = 0,01 sortirait 100 fois trop grand sur le présentoir.
		local rawCf, rawSize = model:GetBoundingBox()
		if math.max(rawSize.X, rawSize.Y, rawSize.Z) > 30 then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local rel = rawCf:ToObjectSpace(d.CFrame)
					d.Size = d.Size * 0.01
					d.CFrame = rawCf * (rel.Rotation + rel.Position * 0.01)
				end
			end
		end
		local itemId = string.sub(name, 5)
		local meshes = {}
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") then table.insert(meshes, d) end
		end
		if #meshes == 0 then table.insert(problems, name .. " : aucun maillage") continue end
		for i, mp in meshes do
			mp.Name = if #meshes == 1 then name else name .. "_" .. i
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			mp.Massless = true
			mp.CastShadow = true
			pcall(function() mp.CollisionFidelity = Enum.CollisionFidelity.Box end)
			if mp.CFrame.UpVector.Y < 0.99 then table.insert(problems, name .. " : maillage pas droit (UpVector " .. tostring(mp.CFrame.UpVector) .. ")") end
		end
		local old = model:FindFirstChild("Root")
		if old then old:Destroy() end
		model.PrimaryPart = nil
		local cf, size = model:GetBoundingBox()
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = size
		root.CFrame = CFrame.new(cf.Position)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = true
		root.CanTouch = false
		root.Massless = true
		root.CastShadow = false
		root.Parent = model
		model.PrimaryPart = root
		-- avec un PrimaryPart, le pivot du modèle vient de Root.PivotOffset (WorldPivot ne sert plus)
		root.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
		model:SetAttribute("ItemId", itemId)
		local existing = Items:FindFirstChild(name)
		if existing then existing:Destroy() end
		model.Parent = Items
		table.insert(done, string.format("%s %.2f×%.2f×%.2f", name, size.X, size.Y, size.Z))
	end
end
for _, src in sources do
	if src.Parent and #src:GetDescendants() == 0 then src:Destroy() end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Objets v3 Meshy rangés")
table.sort(done)
return string.format("%d rangés\n%s\nproblèmes : %s", #done, table.concat(done, "\n"), table.concat(problems, " ; "))

--!nocheck
-- Scénario « size » du banc a142 : l'objet tenu a la taille qu'il a sur un présentoir, pour chaque taille de
-- mutation (aucune, Tiny, Big, Huge, Colossal), avec le modèle ITM_ de Clément (Z3_Smartphone, 3 pièces) et avec le
-- bloc V0 (Z1_Banane, pas livré) ; prise en main (Tool.Grip) selon Config/HeldItem.
advance(1000)
startServer()
local HeldItem = sharedModule("Config/HeldItem")
local sizes = { "None", "Tiny", "Big", "Huge", "Colossal" }
local data = newProfile()
local uids = {}
for _, itemId in { "Z3_Smartphone", "Z1_Banane" } do
	for _, size in sizes do
		local uid = `{itemId}_{size}`
		addItem(data, uid, itemId, nil, if itemId == "Z3_Smartphone" then 3 else 1, 0)
		if size ~= "None" then
			data.Items[uid].Mutation = { Size = size }
		end
		table.insert(uids, uid)
	end
end
local ada = join("Ada", data)
advance(1.5)
startClient(ada)
advance(0.5)
local Mutations = sharedModule("Config/Mutations")

local function nearV(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end
local function fmt(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

for _, uid in uids do
	section(uid)
	advance(0.3)
	fireAs(ada, "PlaceItemAuto", uid)
	flush()
	advance(0.1)
	local shown = displayModelOf(ada, uid)
	check(shown ~= nil, "exposé sur un présentoir")
	if shown == nil then
		continue
	end
	local shownSizes = sizesOf(shown)
	local _, shownBox = boxOf(shown, shown:GetPivot())
	advance(0.3)
	fireAs(ada, "UnplaceItem", uid)
	flush()
	advance(0.3)
	holdAs(ada, uid)
	local tool = heldTool(ada)
	check(tool ~= nil and tool:GetAttribute("HeldItemUid") == uid, "en main")
	if tool == nil then
		continue
	end
	local model = tool:FindFirstChild("HeldItem")
	local heldSizes = sizesOf(model)
	local _, heldBox = boxOf(model, model:GetPivot())
	check(heldSizes == shownSizes, `mêmes pièces, mêmes tailles qu'au présentoir ({heldSizes})`)
	check(nearV(heldBox, shownBox), `même boîte qu'au présentoir : {fmt(heldBox)} / {fmt(shownBox)}`)
	local entry = dataOf(ada).Items[uid]
	local scale = Mutations.Scale(Mutations.Sanitize(entry.Mutation))
	check(model:GetAttribute("MutationSize") == (entry.Mutation and entry.Mutation.Size or nil), `attribut MutationSize ({tostring(model:GetAttribute("MutationSize"))}), échelle {scale}`)
	-- Poignée au centre de la boîte, Grip selon la taille.
	local center = boxOf(model, tool.Handle.CFrame)
	check(nearV(center, Vector3.zero), `poignée au centre de la boîte ({fmt(center)})`)
	local large = math.max(heldBox.X, heldBox.Y, heldBox.Z) > HeldItem.LargeSize
	local expected = Vector3.new(
		if large then -HeldItem.LargeCenterShift else 0,
		if large then heldBox.Y / 2 - HeldItem.LargeBelowHand else 0,
		-(heldBox.Z / 2 + HeldItem.Forward)
	)
	local offset = tool.Grip:Inverse().Position
	check(nearV(offset, expected), `prise en main {if large then "d'un gros objet" else "d'un petit objet"} : {fmt(offset)}`)
	advance(0.3)
	holdAs(ada, uid) -- même uid : rien ne change
	check(heldTool(ada) == tool and #itemTools(ada) == 1, "redemandé : le même Tool, pas de second")
	ada.Character:FindFirstChildOfClass("Humanoid"):UnequipTools()
	advance(0.1)
	check(#itemTools(ada) == 0, "rangé par le client : détruit")
end

section("tailles relatives")
local function heightOf(uid)
	advance(0.3)
	holdAs(ada, uid)
	local tool = heldTool(ada)
	local _, box = boxOf(tool:FindFirstChild("HeldItem"), tool.HeldItem:GetPivot())
	ada.Character:FindFirstChildOfClass("Humanoid"):UnequipTools()
	advance(0.1)
	return box.Y
end
local base = heightOf("Z3_Smartphone_None")
for _, size in { "Tiny", "Big", "Huge", "Colossal" } do
	local k = Mutations.Scale({ Size = size })
	local h = heightOf("Z3_Smartphone_" .. size)
	check(math.abs(h - base * k) <= 1e-3, `{size} : hauteur × {k} ({string.format("%.2f", h)} pour {string.format("%.2f", base)})`)
end

summary("scénario size")

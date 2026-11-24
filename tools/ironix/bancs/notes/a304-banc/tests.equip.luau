---------------------------------------------------------------- scénario « equip » (a304, 21/11 : bouton Equip de la boutique d'armes)
-- Après setup.luau du banc a50 (WeaponShopController branché, ShopService réel). Copie de UI_WeaponShop habillée comme
-- celle de Clément (lue dans Studio le 21/11, en lecture seule) : Root.List.Template.Card.Content.ButtonRow avec
-- BuyButton (Fill.Outline à contour noir, Price) et EquipButton (texte du TextButton, contour 0d0d14, Fill vert à
-- dégradé, Fill.UIStroke blanc, Gloss, Shade, Rim, Lip, Gloss), RobuxButton. Le banc vérifie que notre code ne change
-- rien au style du bouton Equip (couleurs, UIStroke, police, texte, tailles, enfants) dans les états « achetable »,
-- « possédée » et « équipée », ni pendant et après le survol : seuls Visible et Text (« Equip » / « Equipped ») bougent,
-- et l'UIScale passager du survol (retiré au repos), et la transparence de Shade pendant le survol (rendue au repos).
local playerGui = P1.PlayerGui
-- Survol : Motion.Button posé par UiMotionController sur les boutons des écrans (comme dans le jeu).
local ctrl = folder(StarterPlayerScripts.Client, "Controllers304")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseController304"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController304")
local UiMotionController = requireModule(moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau"), "client")
taskLib.spawn(UiMotionController.Start)
local Motion = requireModule(motionModule, "client")
Motion.SetSoundPlayer(function()
	return true
end)
step(0.1)

local function el(root, name)
	return root:FindFirstChild(name, true)
end
local function C(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local function screenGui()
	local screen = new("ScreenGui", { Name = "UI_WeaponShop", Enabled = true })
	screen:SetAttribute("ScreenGroup", "Menu")
	local root = new("Frame", { Name = "Root" }, screen)
	new("TextButton", { Name = "CloseButton", Text = "X" }, root)
	local list = new("ScrollingFrame", { Name = "List" }, root)
	local template = new("Frame", { Name = "Template", Visible = false }, list)
	local card = new("Frame", { Name = "Card", ClipsDescendants = true }, template)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://template" }, card)
	new("TextLabel", { Name = "ItemName", Text = "Tool" }, card)
	new("TextLabel", { Name = "Power", Text = "Power" }, card)
	local content = new("Frame", { Name = "Content" }, card)
	local rowFrame = new("Frame", { Name = "ButtonRow" }, content)
	-- BuyButton (Fill.Outline noir, Price en FredokaOne à contour 113909).
	local buy = new("TextButton", { Name = "BuyButton", Text = "", BackgroundTransparency = 1, ZIndex = 12 }, rowFrame)
	local bfill = new("Frame", { Name = "Fill", BackgroundColor3 = C(255, 255, 255), ZIndex = 13 }, buy)
	local outline = new("Frame", { Name = "Outline", BackgroundTransparency = 1, ZIndex = 13 }, bfill)
	new("UIStroke", { Name = "UIStroke", Color = C(0, 0, 0), Thickness = 2.5 }, outline)
	local price = new("TextLabel", { Name = "Price", Text = "$0", ZIndex = 14 }, buy)
	new("UIStroke", { Name = "UIStroke", Color = C(17, 57, 9), Thickness = 0.16 }, price)
	new("Frame", { Name = "Shade", BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, ZIndex = 16 }, buy)
	-- EquipButton tel que Clément l'a fait (StarterGui, 21/11).
	local equip = new("TextButton", {
		Name = "EquipButton",
		Text = "Equip",
		TextColor3 = C(255, 255, 255),
		FontFace = Font.fromEnum("Enum.Font.Montserrat"),
		TextScaled = true,
		BackgroundTransparency = 1,
		ZIndex = 15,
		Size = UDim2.fromScale(0.62, 1),
		Position = UDim2.fromScale(0.36, 0),
	}, rowFrame)
	new("UIStroke", { Name = "UIStroke", Color = C(13, 13, 20), Thickness = 0.05, Transparency = 0 }, equip)
	new("UICorner", { Name = "UICorner" }, equip)
	new("UIPadding", { Name = "UIPadding" }, equip)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0, ZIndex = 13, Size = UDim2.fromScale(1.19, 1.39) }, equip)
	new("UIGradient", { Name = "UIGradient", Color = ColorSequence.new(C(229, 255, 78), C(72, 255, 20)) }, fill)
	local fstroke = new("UIStroke", { Name = "UIStroke", Color = C(255, 255, 255), Thickness = 2.5, Transparency = 0.35 }, fill)
	new("UIGradient", { Name = "StrokeGradient", Color = ColorSequence.new(C(106, 173, 78), C(72, 147, 41)) }, fstroke)
	new("UICorner", { Name = "UICorner" }, fill)
	new("Frame", { Name = "Gloss", BackgroundColor3 = C(255, 255, 255), ZIndex = 13, Size = UDim2.fromScale(1, 0.5) }, fill)
	new("ImageLabel", { Name = "Studs", BackgroundTransparency = 1, ZIndex = 13 }, fill)
	new("Frame", { Name = "Shade", BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 1, ZIndex = 16 }, equip)
	new("Frame", { Name = "Lip", BackgroundColor3 = C(18, 157, 3), ZIndex = 12 }, equip)
	local rim = new("Frame", { Name = "Rim", BackgroundTransparency = 1, ZIndex = 12 }, equip)
	new("UIStroke", { Name = "UIStroke", Color = C(255, 255, 255), Thickness = 1.5, Transparency = 0.35 }, rim)
	new("Frame", { Name = "Gloss", BackgroundColor3 = C(255, 255, 255), ZIndex = 12 }, equip)
	new("TextButton", { Name = "RobuxButton", Text = "", ZIndex = 12 }, rowFrame)
	screen.Parent = playerGui
	return screen, list
end

local function row(list, toolId)
	for _, child in list:GetChildren() do
		if string.match(child.Name, "_" .. toolId .. "$") then
			return child
		end
	end
	return nil
end

-- Style d'un élément et de ses descendants (sauf l'UIScale passager du survol), en texte comparable.
local PROPS = {
	"ClassName", "Text", "TextColor3", "FontFace", "TextScaled", "BackgroundColor3", "BackgroundTransparency", "ZIndex",
	"Size", "Position", "AnchorPoint", "Color", "Thickness", "Transparency", "Image",
}
local function show(v)
	local t = typeof(v)
	if t == "table" then
		local keys = {}
		for k in v do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		local parts = {}
		for _, k in keys do
			table.insert(parts, k .. "=" .. show(v[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "number" then
		return string.format("%.6f", v)
	end
	return tostring(v)
end
local function styleOf(object, skip)
	local lines = {}
	local function walk(o, path)
		if o:IsA("UIScale") then
			return
		end
		local parts = { path }
		for _, p in PROPS do
			if not (skip and skip[path .. "." .. p]) then
				local ok, v = pcall(function()
					return (o :: any)[p]
				end)
				if ok and v ~= nil then
					table.insert(parts, p .. "=" .. show(v))
				end
			end
		end
		table.insert(lines, table.concat(parts, " "))
		local kids = o:GetChildren()
		table.sort(kids, function(a, b)
			return a.Name < b.Name or (a.Name == b.Name and a.ClassName < b.ClassName)
		end)
		for i, k in kids do
			walk(k, path .. "/" .. k.Name .. "#" .. i)
		end
	end
	walk(object, "EquipButton")
	return table.concat(lines, "\n")
end
local function firstDiff(a, b)
	local la, lb = string.split(a, "\n"), string.split(b, "\n")
	for i = 1, math.max(#la, #lb) do
		if la[i] ~= lb[i] then
			return `{la[i] or "(rien)"}  ≠  {lb[i] or "(rien)"}`
		end
	end
	return ""
end
-- Texte à part : « Equip » ou « Equipped » selon l'état (c'est le seul champ que le code écrit).
local NO_TEXT = { ["EquipButton.Text"] = true }

print("-- Bouton Equip a304")
local screen, list = screenGui()
step(0.1)
local template = el(list, "Template")
local ref = styleOf(el(template, "EquipButton"), NO_TEXT)
check(logCount("[WeaponShop] UI_WeaponShop branché : 7 outil(s)", "PRINT", "client") >= 1, "E0 écran branché : 7 outils")

local function rowStyle(id, skip)
	return styleOf(el(row(list, id), "EquipButton"), skip or NO_TEXT)
end
local function allSame(label)
	local okAll, diff = true, ""
	for _, id in { "Fists", "Wrench", "Crowbar", "Hammer", "Sledgehammer", "FireAxe", "AngleGrinder" } do
		local s = rowStyle(id)
		if s ~= ref then
			okAll = false
			diff = id .. " : " .. firstDiff(s, ref)
			break
		end
	end
	check(okAll, `{label} : style d'Equip identique au Template de Clément sur les 7 lignes {diff}`)
end

-- État de départ : Fists possédé et équipé, les autres achetables.
local fistsEquip = el(row(list, "Fists"), "EquipButton")
local wrenchEquip = el(row(list, "Wrench"), "EquipButton")
check(fistsEquip.Visible == true and fistsEquip.Text == "Equipped" and el(row(list, "Fists"), "BuyButton").Visible == false, "E1 Fists équipé : Equip visible, « Equipped »")
check(wrenchEquip.Visible == false and el(row(list, "Wrench"), "BuyButton").Visible == true, "E2 Wrench achetable : Buy visible, Equip caché")
check(el(template, "EquipButton").Text == "Equip" and el(template, "EquipButton").Visible == true, "E3 Template intact (texte « Equip »)")
allSame("E4 achetable et équipée")

-- Achat de Wrench : il est équipé, Fists passe à « Equip » (possédée).
setCash(P1, 10000)
el(row(list, "Wrench"), "BuyButton").Activated:Fire()
step(0.1)
check(wrenchEquip.Visible == true and wrenchEquip.Text == "Equipped" and fistsEquip.Visible == true and fistsEquip.Text == "Equip", "E5 Wrench acheté et équipé, Fists possédé : « Equipped » / « Equip »")
allSame("E6 après l'achat (possédée, équipée)")

-- Equip sur Fists : retour, Wrench repasse à « Equip ».
step(1.1)
fistsEquip.Activated:Fire()
step(0.2)
check(fistsEquip.Text == "Equipped" and wrenchEquip.Text == "Equip" and P1:GetAttribute("EquippedTool") == "Fists", "E7 Equip sur Fists : « Equipped », Wrench « Equip »")
allSame("E8 après Equip")

-- Survol de l'Equip de Wrench (possédée) : pendant, seuls l'UIScale passager et Shade bougent ; après, tout est rendu.
local shade = wrenchEquip:FindFirstChild("Shade")
local shadeRest = shade.BackgroundTransparency
Motion.Button(wrenchEquip) -- comme UiMotionController (sans effet de plus s'il est déjà branché)
wrenchEquip.MouseEnter:Fire()
step(0.3)
local during = styleOf(wrenchEquip, NO_TEXT)
-- Rangs retirés (l'UIScale passager, sauté par styleOf, décale le rang des frères) ; transparence de Shade à part.
local function stripRanks(s)
	return (string.gsub(s, "#%d+", ""))
end
local function stripShade(s)
	local out = {}
	for _, line in string.split(s, "\n") do
		if string.match(line, "^EquipButton/Shade ") then
			line = string.gsub(line, " BackgroundTransparency=[%d%.%-]+", "")
		elseif string.match(line, "^EquipButton ") then
			-- a299 (survol centré) : AnchorPoint à (0,5 ; 0,5) et Position décalée d'autant le temps du survol.
			line = string.gsub(string.gsub(line, " Position=%b{}", ""), " AnchorPoint=%b{}", "")
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end
local d1, d2 = stripShade(stripRanks(during)), stripShade(stripRanks(ref))
check(d1 == d2, `E9 pendant le survol : couleurs, UIStroke, police et tailles d'Equip inchangées {if d1 == d2 then "" else firstDiff(d1, d2)}`)
check(wrenchEquip:FindFirstChildWhichIsA("UIScale") ~= nil and el(row(list, "Wrench"), "BuyButton"):FindFirstChildWhichIsA("UIScale") == nil, "E10 le survol grossit Equip (UIScale passager), pas Buy caché dessous")
check(wrenchEquip.Text == "Equip", "E11 pendant le survol : texte « Equip » gardé")
wrenchEquip.MouseLeave:Fire()
step(0.6)
check(wrenchEquip:FindFirstChildWhichIsA("UIScale") == nil and shade.BackgroundTransparency == shadeRest, "E12 après le survol : UIScale retiré, Shade rendu à sa transparence de repos")
allSame("E13 après le survol")
check(logCount("[WeaponShop]", "WARN", "client") == 0, "E14 aucun avertissement de la boutique")
summary()

--!nonstrict
-- ui_hud_tuiles_rectangle.luau (Clément, 2026-11-21) : les tuiles « zZz » et « x2 SPEED » du HUD passent au style de
-- ses boutons Framewisp, en rectangle avec une description (« refais les boutons au style du display », puis « Fais
-- les en rectangle pour la description »). Maquette : docs/claude/video/references/2026-11-21_ShopTikTok/frames/
-- hud_tuiles_rectangle_maquette.png. Fiche : docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, section 12.
-- Remplace l'habillage carré de ui_hud_tuiles_speed_sleep.luau.
--
-- Ce qui reste pour le code (HudMenuController, Config/Boosts) : les boutons UI_HUD.RightRail.SleepButton et
-- SpeedBoostButton (mêmes objets, classe, place, attributs), Price.Amount (le prix, écrit par le code), Price.RobuxIcon
-- et Cooldown (voile de recharge, montré par le code). Ils restent cachés : le code les montre selon leur règle
-- (x2 SPEED sur un tapis, zZz dans le couloir, zone 1 et plus).
-- Habillage : fond, rayons et cadre des boutons PC de Clément (SleepButton = bleu d'Index, Framewisp_9BEJ6Z ;
-- SpeedBoostButton = vert de Shop, Framewisp_5C9UZM), icône d'avant, titre (Label) et description (Hint) :
--   zZz      « Guards sleep 60s »   (Config/Boosts : SleepGuards, Duration = 60 ; texte d'origine de Clément)
--   x2 SPEED « x2 gains · 10 min »  (Config/Boosts : SpeedBoost, Multiplier = 2, Duration = 600 ; court pour rester lisible sur téléphone)
-- Rectangle au rapport 3,222 (celui des boutons PC), sur toute la largeur de RightRail, avec au moins 142 × 44 px
-- (règle du téléphone : 44 px de haut au moins). Aucun script ; rayons avec SpinSpeed = 45 (à coder, section 8).
-- Display à 125 % (2026-11-22) : DisplayedButton agrandi, tuiles à Y 0,7175 (voir la fin du script).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-21_HUD_TuilesRect/UI_HUD (et 2026-11-22_HUD_Display125). Rejouable,
-- annulable en une étape.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local HUD = SG:WaitForChild("UI_HUD")
local RR = HUD:WaitForChild("RightRail")
local SOURCES = SS:WaitForChild("MapBackups"):WaitForChild("2026-11-21_HUD_Framewisp")

local TILES = {
	{ button = "SleepButton", code = "9BEJ6Z", icon = "rbxassetid://81902433249804", title = "zZz", hint = "Guards sleep 60s" },
	{ button = "SpeedBoostButton", code = "5C9UZM", icon = "rbxassetid://114903617420676", title = "x2 SPEED", hint = "x2 gains · 10 min" },
}
local KEEP = { Price = true, Cooldown = true } -- lus par le code
local Z_BASE = 3

local recording = CHS:TryBeginRecording("HUD : tuiles zZz et x2 SPEED en rectangle")

local mb = SS.MapBackups
local bf = mb:FindFirstChild("2026-11-21_HUD_TuilesRect") or Instance.new("Folder")
bf.Name = "2026-11-21_HUD_TuilesRect"
bf.Parent = mb
if not bf:FindFirstChild("UI_HUD") then HUD:Clone().Parent = bf end

local function rootOf(g) for _, c in ipairs(g:GetChildren()) do if c:IsA("GuiObject") then return c end end end
local function all(o) return { o, table.unpack(o:GetDescendants()) } end

local report = {}
for _, t in TILES do
	local btn = RR:FindFirstChild(t.button)
	local src = SOURCES:FindFirstChild("Framewisp_" .. t.code)
	if not (btn and btn:IsA("GuiButton") and src) then table.insert(report, t.button .. " : bouton ou dessin introuvable") continue end
	local root = rootOf(src)
	for _, c in ipairs(btn:GetChildren()) do if not KEEP[c.Name] then c:Destroy() end end
	btn.BackgroundTransparency = 1
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.fromScale(1, 0.6 + 0.25 * 0.47) -- 0,523 puis 0,6 (le prix touchait Display au rebond) ; 0,7175 depuis Display à 125 %
	btn.Size = UDim2.fromScale(0.88, 0.33) -- 88 % : au rebond, la tuile restait 2,5 px avant le bord de l'écran (PC)
	local arc = Instance.new("UIAspectRatioConstraint")
	arc.AspectRatio = 3.222
	arc.Parent = btn
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(142, 44)
	minSize.Parent = btn
	-- calques du dessin, sans scripts ni réglages du plugin
	local added = {}
	for _, c in ipairs(root:GetChildren()) do
		if not (c:IsA("LuaSourceContainer") or c:IsA("UIAspectRatioConstraint")) then
			local cl = c:Clone()
			for _, d in ipairs(all(cl)) do
				if d == cl or d.Parent then
					if d:IsA("LuaSourceContainer") or d.Name == "FW_Scale" or (d:IsA("NumberValue") and d.Name == "k_text") then
						d:Destroy()
					else
						for k in d:GetAttributes() do if k:match("^FW_") or k:match("^BB_") then d:SetAttribute(k, nil) end end
						if d:IsA("GuiObject") and d.Name:sub(1, #root.Name) == root.Name and #d.Name > #root.Name then d.Name = (d.Name:sub(#root.Name + 1):gsub("^_", "")) end
						if d:IsA("ImageLabel") and d.Name == "Sunburst" then
							d.Position = UDim2.fromScale(0.217241377, 0.574999988)
							d:SetAttribute("SpinSpeed", d:GetAttribute("FigmaSpinSpeed") or 45)
						end
						if d:IsA("ImageLabel") and d.Name == "Icon" then d.Image = t.icon end
						if d:IsA("ImageLabel") and d.Name == "BurstImg" then d.Image = t.icon end
					end
				end
			end
			-- UI_HUD est en ZIndexBehavior Global : un CanvasGroup n'y coupe pas ; les rayons vont dans le cadre, qui coupe
			for _, cg in ipairs(cl:GetDescendants()) do
				if cg:IsA("CanvasGroup") and cg:FindFirstChild("Sunburst") then
					for _, c2 in ipairs(cg:GetChildren()) do if c2:IsA("GuiObject") then c2.Parent = cg.Parent end end
					cg.Parent.ClipsDescendants = true
					cg:Destroy()
				end
			end
			table.insert(added, cl)
		end
	end
	-- titre et description
	local label, shadow
	for _, cl in added do
		if cl:IsA("TextLabel") and cl.Name == "Label" then label = cl end
		if cl:IsA("TextLabel") and cl.Name == "LabelShadow" then shadow = cl end
	end
	for i, l in { label, shadow } do
		l.Text = t.title
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Size = UDim2.fromScale(0.6, 0.36)
		l.Position = UDim2.fromScale(0.665, i == 1 and 0.31 or 0.343)
	end
	local hint = label:Clone()
	hint.Name = "Hint"
	hint.Text = t.hint
	hint.Size = UDim2.fromScale(0.6, 0.24)
	hint.Position = UDim2.fromScale(0.665, 0.68)
	hint.FontFace = Font.new(label.FontFace.Family, Enum.FontWeight.Bold)
	local hs = hint:FindFirstChildOfClass("UIStroke")
	if hs then hs.Thickness *= 0.8 end
	table.insert(added, hint)
	-- ZIndex ramenés de Z_BASE à Z_BASE + n, dans le même ordre
	local zs, seen = {}, {}
	for _, cl in added do for _, d in ipairs(all(cl)) do if d:IsA("GuiObject") and not seen[d.ZIndex] then seen[d.ZIndex] = true table.insert(zs, d.ZIndex) end end end
	table.sort(zs)
	local rank = {}
	for i, z in zs do rank[z] = Z_BASE + i - 1 end
	for _, cl in added do
		for _, d in ipairs(all(cl)) do if d:IsA("GuiObject") then d.ZIndex = rank[d.ZIndex] end end
		cl.Parent = btn
	end
	local top = Z_BASE + #zs
	-- prix (lu par le code) : étiquette sur le coin en haut à droite
	local price = btn:FindFirstChild("Price")
	if price then
		price.AnchorPoint = Vector2.new(1, 0.5)
		price.Size = UDim2.fromScale(0.21, 0.29)
		price.Position = UDim2.fromScale(1.02, 0.02)
		local base = price.ZIndex
		for _, d in ipairs(all(price)) do if d:IsA("GuiObject") then d.ZIndex = top + (d.ZIndex - base) end end
	end
	-- voile de recharge (montré par le code) : sur la face du bouton, au-dessus de tout
	local cd = btn:FindFirstChild("Cooldown")
	if cd and cd:IsA("GuiObject") then
		cd.AnchorPoint = Vector2.new(0, 0)
		cd.Position = UDim2.fromScale(0, 0)
		cd.Size = UDim2.fromScale(1, 0.89)
		cd.ZIndex = top + 4
		local corner = cd:FindFirstChildOfClass("UICorner")
		if corner then corner.CornerRadius = UDim.new(0.12, 0) end
		local pad = cd:FindFirstChildOfClass("UIPadding")
		if pad then pad.PaddingTop = UDim.new(0.22, 0) pad.PaddingBottom = UDim.new(0.22, 0) pad.PaddingLeft = UDim.new(0.3, 0) pad.PaddingRight = UDim.new(0.3, 0) end
	end
	table.insert(report, ("%s <- Framewisp_%s : %d calques, ZIndex %d à %d, prix %s, voile %s"):format(t.button, t.code, #added, Z_BASE, top + 4, price and "gardé" or "ABSENT", cd and "gardé" or "ABSENT"))
end

-- Display à 125 % (choix de Clément, 2026-11-22 : « Oui, Display 125 % » ; maquette hud_display_taille_options.png) :
-- le bouton grandit de 25 % depuis son coin haut droit, les tuiles descendent d'autant (0,25 × sa hauteur, 0,47 du rail).
local disp = RR:FindFirstChild("DisplayedButton")
if disp and disp:IsA("GuiObject") then
	local target = UDim2.fromScale(0.4148148 * 1.25, 0.4307692 * 1.25)
	if disp.Size ~= target then
		local bk = SS.MapBackups:FindFirstChild("2026-11-22_HUD_Display125") or Instance.new("Folder")
		bk.Name = "2026-11-22_HUD_Display125" bk.Parent = SS.MapBackups
		if not bk:FindFirstChild("UI_HUD") then HUD:Clone().Parent = bk end
		disp.Size = target
	end
	table.insert(report, "DisplayedButton à 125 %")
end

if recording then CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
local scripts = 0
for _, d in ipairs(SG:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
table.insert(report, "scripts dans StarterGui : " .. scripts)
return table.concat(report, "\n")

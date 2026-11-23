--!nonstrict
-- ui_hud_boutons_framewisp.luau (Clément, 2026-11-21) : les boutons Shop, Index, Upgrades et Displays du HUD prennent
-- les dessins que Clément a faits avec le plugin Framewisp (« J'ai ajouté des boutons sur roblox studio, tu peux les
-- remplacer de ce actuellement ? », puis « je te fais les versions responsives » : versions téléphone à part).
-- Fiche : docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, section 11.
--
-- Ce qui change : seulement l'habillage. Les boutons lus par le code restent les mêmes objets, avec leurs noms, leur
-- classe (TextButton), leur place dans LeftRail / LeftRailTouch / RightRail, leurs attributs (Hover, IconHover, Press)
-- et leurs pastilles (IndexAlert, SkillTreeAlert). Leurs anciens calques (Studs, Shine, Icon, Label, Lip, Rim, contour,
-- dégradé, coins) sont remplacés par ceux du dessin Framewisp :
--   LeftRail.RobuxShopButton  <- Framewisp_5C9UZM (Shop, 290 × 90)     LeftRailTouch.RobuxShopButton <- Framewisp_YMN8Y4
--   LeftRail.IndexButton      <- Framewisp_9BEJ6Z (Index, 290 × 90)    LeftRailTouch.IndexButton     <- Framewisp_988SNX
--   LeftRail.SkillTreeButton  <- Framewisp_D2JPMH (Upgrades, 290 × 90) LeftRailTouch.SkillTreeButton <- Framewisp_UYPUAN
--   RightRail.DisplayedButton <- Framewisp_ZDLZ89 (Display, 94 × 102 ; la 1re version, QMN9WW, reste dans la sauvegarde)
-- Aucun script : les LocalScripts Framewisp (texte, reflet, éclat, rotation, contour) ne sont pas copiés (pas de script
-- dans l'UI). Les réglages d'effet du dessin sont gardés en attributs pour le code d'Ironix : Figma* (FigmaGleam,
-- FigmaBurst, FigmaLean, FigmaWiggle, FigmaStroke…) et SpinSpeed sur les rayons (Sunburst).
-- Ordre d'affichage : UI_HUD est en ZIndexBehavior Global ; les ZIndex du dessin (4 à 24) sont ramenés de 3 à 14 dans le
-- même ordre, sous les pastilles (20). Dans ce mode, les masques CanvasGroup du dessin ne coupent pas les rayons : ils
-- sont remplacés par une coupe simple (ClipsDescendants) sur leur cadre (coins droits au lieu d'arrondis, à peine visible).
-- Sauvegardes : ServerStorage/MapBackups/2026-11-21_HUD_Framewisp/UI_HUD (copie d'avant), et les 7 écrans Framewisp
-- d'origine, sortis de StarterGui et rangés au même endroit (ils contenaient des scripts et s'affichaient au milieu de
-- l'écran en jeu). Rejouable : un 2e passage refait la même chose à partir des écrans rangés. Annulable en une étape.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local HUD = SG:WaitForChild("UI_HUD")
local BACKUP = "2026-11-21_HUD_Framewisp"

local MAP = {
	{ code = "5C9UZM", target = "LeftRail.RobuxShopButton" },
	{ code = "9BEJ6Z", target = "LeftRail.IndexButton" },
	{ code = "D2JPMH", target = "LeftRail.SkillTreeButton" },
	{ code = "YMN8Y4", target = "LeftRailTouch.RobuxShopButton" },
	{ code = "988SNX", target = "LeftRailTouch.IndexButton" },
	{ code = "UYPUAN", target = "LeftRailTouch.SkillTreeButton" },
	{ code = "ZDLZ89", target = "RightRail.DisplayedButton" }, -- 2e version de Display (94 × 102), au lieu de QMN9WW (220 × 228),
}
local Z_BASE = 3 -- premier ZIndex des calques du dessin (comme les anciens calques)
local BUTTON_FX = { "FigmaGleam", "FigmaGleamWidth", "FigmaBurst", "FigmaBurstSize", "FigmaBurstSizeMax", "FigmaBurstW", "FigmaBurstH", "FigmaSmooth" }

local recording = CHS:TryBeginRecording("HUD : boutons Framewisp")

-- 1. Sauvegardes
local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder")
mb.Name = "MapBackups"
mb.Parent = SS
local bf = mb:FindFirstChild(BACKUP) or Instance.new("Folder")
bf.Name = BACKUP
bf.Parent = mb
if not bf:FindFirstChild("UI_HUD") then HUD:Clone().Parent = bf end

-- les écrans Framewisp : dans StarterGui (1er passage) ou déjà rangés (passages suivants)
local sources = {}
for _, holder in { SG, bf } do
	for _, g in ipairs(holder:GetChildren()) do
		local code = g:IsA("ScreenGui") and g:GetAttribute("FW_Code")
		if code then sources[code] = g end
	end
end
for _, g in sources do
	if g.Parent == SG then g.Enabled = false g.Parent = bf end
end

local function find(path)
	local p = HUD
	for part in path:gmatch("[^%.]+") do p = p and p:FindFirstChild(part) end
	return p
end
local function rootOf(g)
	for _, c in ipairs(g:GetChildren()) do if c:IsA("GuiObject") then return c end end
end
local function clean(o, prefix)
	for _, d in ipairs({ o, table.unpack(o:GetDescendants()) }) do
		if d == o or d.Parent then -- la copie n'a pas encore de parent ; un enfant détruit n'en a plus
			if d:IsA("LuaSourceContainer") or d.Name == "FW_Scale" or (d:IsA("NumberValue") and d.Name == "k_text") then
				d:Destroy()
			else
				for k in d:GetAttributes() do if k:match("^FW_") or k:match("^BB_") then d:SetAttribute(k, nil) end end
				if d:IsA("GuiObject") and d.Name:sub(1, #prefix) == prefix and #d.Name > #prefix then
					d.Name = (d.Name:sub(#prefix + 1):gsub("^_", ""))
				end
				if d:IsA("GuiObject") and d.Name == "Sunburst" and d:GetAttribute("FigmaSpin") then
					d:SetAttribute("SpinSpeed", d:GetAttribute("FigmaSpinSpeed") or 45)
				end
			end
		end
	end
end

-- 2. Habillage des boutons
local report = {}
for _, m in MAP do
	local btn, src = find(m.target), sources[m.code]
	if not (btn and btn:IsA("GuiButton")) then table.insert(report, m.target .. " : bouton introuvable") continue end
	if not src then table.insert(report, m.target .. " : écran Framewisp_" .. m.code .. " introuvable") continue end
	local root = rootOf(src)
	-- anciens calques retirés (ils restent dans la sauvegarde), sauf la pastille et la contrainte de forme
	for _, c in ipairs(btn:GetChildren()) do
		if not (c.Name:match("Alert$") or c:IsA("UIAspectRatioConstraint")) then c:Destroy() end
	end
	btn.BackgroundTransparency = 1
	local ratio = root:FindFirstChildOfClass("UIAspectRatioConstraint")
	local arc = btn:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not arc then
		arc = Instance.new("UIAspectRatioConstraint")
		arc.Parent = btn
	end
	if ratio then arc.AspectRatio = ratio.AspectRatio end
	-- calques du dessin, sans scripts ni réglages du plugin
	local added = {}
	for _, c in ipairs(root:GetChildren()) do
		if not (c:IsA("LuaSourceContainer") or c:IsA("UIAspectRatioConstraint")) then
			local cl = c:Clone()
			clean(cl, root.Name)
			table.insert(added, cl)
		end
	end
	-- ZIndex ramenés de Z_BASE à Z_BASE + n, dans le même ordre
	local zs, seen = {}, {}
	for _, cl in added do for _, d in ipairs({ cl, table.unpack(cl:GetDescendants()) }) do if d:IsA("GuiObject") and not seen[d.ZIndex] then seen[d.ZIndex] = true table.insert(zs, d.ZIndex) end end end
	table.sort(zs)
	local rank = {}
	for i, z in zs do rank[z] = Z_BASE + i - 1 end
	for _, cl in added do
		for _, d in ipairs({ cl, table.unpack(cl:GetDescendants()) }) do if d:IsA("GuiObject") then d.ZIndex = rank[d.ZIndex] end end
		-- UI_HUD est en ZIndexBehavior Global : un CanvasGroup n'y coupe pas ses enfants (ni sa propre coupe, ni celle
		-- de son parent), et les rayons débordaient autour des boutons. Les rayons (et l'icône des versions carrées)
		-- sortent du masque et vont dans son cadre, qui coupe (ClipsDescendants) ; le masque est retiré.
		for _, cg in ipairs(cl:GetDescendants()) do
			if cg:IsA("CanvasGroup") and cg:FindFirstChild("Sunburst") then
				for _, c in ipairs(cg:GetChildren()) do if c:IsA("GuiObject") then c.Parent = cg.Parent end end
				cg.Parent.ClipsDescendants = true
				cg:Destroy()
			end
		end
		cl.Parent = btn
	end
	for _, k in BUTTON_FX do btn:SetAttribute(k, root:GetAttribute(k)) end
	for _, c in ipairs(btn:GetChildren()) do if c.Name:match("Alert$") and c:IsA("GuiObject") then c.ZIndex = math.max(c.ZIndex, Z_BASE + #zs + 2) end end
	table.insert(report, ("%s <- Framewisp_%s : %d calques, ZIndex %d à %d, forme %.3f"):format(m.target, m.code, #added, Z_BASE, Z_BASE + #zs - 1, arc.AspectRatio))
end

-- 3. Écart du rail PC : l'icône de Shop dépasse en bas ; à 6,6 % du rail, Shop et Index se touchaient au rebond de
-- l'appui (× 1,21). À 8,6 %, il reste au moins 2 px au rebond et 6 px au survol (les boutons, au rapport 3,22 au lieu
-- de 3,14, sont un peu plus bas : la colonne ne grandit que de 4 px). Sur téléphone, l'écart d'origine suffit (5 px).
local railLayout = HUD.LeftRail:FindFirstChildOfClass("UIListLayout")
if railLayout then railLayout.Padding = UDim.new(0.0856, 0) end
-- 4. Rayons de Shop (PC) : dans l'écran Framewisp d'origine, son script de rotation les avait laissés à (−1,69 ; −1,86),
-- hors du bouton ; remis à la place de ceux d'Index et d'Upgrades.
local shopGroup = HUD.LeftRail:FindFirstChild("RobuxShopButton") and HUD.LeftRail.RobuxShopButton:FindFirstChild("Group 1")
local shopRays = shopGroup and shopGroup:FindFirstChild("Sunburst")
if shopRays then shopRays.Position = UDim2.fromScale(0.217241377, 0.574999988) end

if recording then CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
local scripts = 0
for _, d in ipairs(SG:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
table.insert(report, "scripts dans StarterGui : " .. scripts)
return table.concat(report, "\n")

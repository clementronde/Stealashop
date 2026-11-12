--[[
	Inventaire : remettre les noms que le code et le contrat lisent (2026-11-11).
	Le 2026-11-11 au matin, l'onglet des armes avait été renommé WeaponsTab / WeaponsSection avant que le
	code et Contract/UI.luau ne changent : en Play, « Tabs.ToolsTab introuvable » et « ToolsSection
	introuvable » (onglet vide, deux lignes rouges du ContractChecker). Le joueur voit toujours « WEAPONS ».
	À lancer en Edit. Annulable (Ctrl+Z).
	- WeaponsTab → ToolsTab, WeaponsSection → ToolsSection (texte « WEAPONS », icône de la batte, ordre gardés).
	- Ajoute ce que le contrat demande encore dans ToolsSection : SectionCount.CountLabel (copie de celui de
	  BoxesSection) et, dans Cards.Template, Rays et Glow (copies de ceux de la carte de BoxesSection).
]]

local CH = game:GetService("ChangeHistoryService")
local rec = CH:TryBeginRecording("Inventaire : ToolsTab et ToolsSection remis, contrat complet")
local inv = game.StarterGui.UI_Inventory
local out = {}

local tab = inv:FindFirstChild("WeaponsTab", true)
if tab then tab.Name = "ToolsTab"; table.insert(out, "onglet renommé") end
local sec = inv:FindFirstChild("WeaponsSection", true)
if sec then sec.Name = "ToolsSection"; table.insert(out, "rubrique renommée") end

local tools = inv:FindFirstChild("ToolsSection", true)
local boxes = inv:FindFirstChild("BoxesSection", true)
if tools and boxes then
	if not tools:FindFirstChild("SectionCount") and boxes:FindFirstChild("SectionCount") then
		local c = boxes.SectionCount:Clone()
		c.Parent = tools
		table.insert(out, "SectionCount ajouté")
	end
	local tTpl = tools:FindFirstChild("Cards") and tools.Cards:FindFirstChild("Template")
	local bTpl = boxes:FindFirstChild("Cards") and boxes.Cards:FindFirstChild("Template")
	if tTpl and bTpl then
		for _, n in { "Rays", "Glow" } do
			if not tTpl:FindFirstChild(n) and bTpl:FindFirstChild(n) then
				local c = bTpl[n]:Clone()
				c.Parent = tTpl
				table.insert(out, n .. " ajouté")
			end
		end
	end
end

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(out, ", ")

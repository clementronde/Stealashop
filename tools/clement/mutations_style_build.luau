-- Design des 7 mutations d'effet (Config/Mutations) dans l'UI et sur les objets (Clément, 2026-11-13).
-- À lancer en Edit. Annulable avec Ctrl+Z. Relançable. Aucun script.
--
-- UI : ReplicatedStorage/Assets/UI/MutationStyles/<Id> (Folder), Id = Shiny, Gold, Neon, Diamond,
--      Glitch, Hacked, Rainbow, plus Size (mutation de taille seule) :
--        TagGradient (UIGradient) : fond d'une étiquette (MutationTag de l'inventaire, onglets de l'Index)
--        TextGradient (UIGradient) : texte coloré (ligne Mutation de BB_Item)
--        attributs LabelColor (Color3, texte posé sur l'étiquette), StrokeColor (Color3, contours),
--        Motion (texte : None, Shine, Pulse, Glitch, Scan, Spin) et MotionPeriod (secondes).
--      Les onglets ShinyTab…RainbowTab de UI_Index_v3 reçoivent leur style ici (statique).
-- Les effets sur les objets sont dans tools/clement/mutations_fx_build.luau (v2) et leur aperçu
-- animé dans tools/clement/mutations_proto.luau.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local recording = ChangeHistoryService:TryBeginRecording("Styles des mutations")

local function need(parent: Instance, path: string): any
	local current: Instance = parent
	for segment in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(segment)
		assert(child, segment .. " introuvable dans " .. current:GetFullName())
		current = child
	end
	return current
end

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- Suite de couleurs : { {temps, "hex"}, … }
local function seq(points: { { any } }): ColorSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], hex(p[2])))
	end
	return ColorSequence.new(keys)
end

type UiStyle = {
	Colors: ColorSequence,
	Rotation: number,
	Label: string,
	Stroke: string,
	Motion: string,
	Period: number,
}

local UI_STYLES: { [string]: UiStyle } = {
	Shiny = {
		Colors = seq({ { 0, "C9D6EC" }, { 0.4, "EEF3FB" }, { 0.5, "FFFFFF" }, { 0.6, "EEF3FB" }, { 1, "C9D6EC" } }),
		Rotation = 20, Label = "FFFFFF", Stroke = "2E3B5C", Motion = "Shine", Period = 2.5,
	},
	Gold = {
		Colors = seq({ { 0, "F2A516" }, { 0.4, "FFD54A" }, { 0.5, "FFF6C2" }, { 0.6, "FFD54A" }, { 1, "F2A516" } }),
		Rotation = 20, Label = "FFFFFF", Stroke = "6B3A00", Motion = "Shine", Period = 2,
	},
	Neon = {
		Colors = seq({ { 0, "FF3FD5" }, { 0.5, "C13BFF" }, { 1, "7A2CFF" } }),
		Rotation = 0, Label = "FFFFFF", Stroke = "3B0057", Motion = "Pulse", Period = 1.6,
	},
	Diamond = {
		Colors = seq({ { 0, "59B8FF" }, { 0.4, "A6ECFF" }, { 0.5, "FFFFFF" }, { 0.6, "A6ECFF" }, { 1, "59B8FF" } }),
		Rotation = 20, Label = "FFFFFF", Stroke = "0C2F5C", Motion = "Shine", Period = 1.5,
	},
	Glitch = {
		Colors = seq({
			{ 0, "FF2E88" }, { 0.32, "FF2E88" }, { 0.33, "2B2B44" }, { 0.66, "2B2B44" }, { 0.67, "2EFFF0" }, { 1, "2EFFF0" },
		}),
		Rotation = 0, Label = "FFFFFF", Stroke = "000000", Motion = "Glitch", Period = 0.8,
	},
	Hacked = {
		Colors = seq({ { 0, "0E7A26" }, { 0.45, "06240C" }, { 0.5, "3DFF5A" }, { 0.55, "06240C" }, { 1, "06240C" } }),
		Rotation = 90, Label = "7CFF6B", Stroke = "001A05", Motion = "Scan", Period = 1.5,
	},
	Rainbow = {
		Colors = seq({
			{ 0, "FF4D4D" }, { 0.17, "FFA63D" }, { 0.33, "FFE94D" }, { 0.5, "5CFF6B" }, { 0.67, "4DC3FF" }, { 0.83, "9B6BFF" }, { 1, "FF6BE1" },
		}),
		Rotation = 0, Label = "FFFFFF", Stroke = "2B1240", Motion = "Spin", Period = 3,
	},
	Size = {
		Colors = seq({ { 0, "B7C7DD" }, { 1, "7F95B3" } }),
		Rotation = 90, Label = "FFFFFF", Stroke = "1F2C40", Motion = "None", Period = 0,
	},
}

-- 1. Styles d'UI
local uiAssets = need(ReplicatedStorage, "Assets.UI")
local oldStyles = uiAssets:FindFirstChild("MutationStyles")
if oldStyles then
	oldStyles:Destroy()
end
local styles = Instance.new("Folder")
styles.Name = "MutationStyles"
for id, style in UI_STYLES do
	local folder = Instance.new("Folder")
	folder.Name = id
	folder:SetAttribute("LabelColor", hex(style.Label))
	folder:SetAttribute("StrokeColor", hex(style.Stroke))
	folder:SetAttribute("Motion", style.Motion)
	folder:SetAttribute("MotionPeriod", style.Period)
	for _, gradientName in { "TagGradient", "TextGradient" } do
		local g = Instance.new("UIGradient")
		g.Name = gradientName
		g.Color = style.Colors
		g.Rotation = if gradientName == "TextGradient" and style.Rotation == 20 then 0 else style.Rotation
		g.Parent = folder
	end
	folder.Parent = styles
end
styles.Parent = uiAssets

-- 2. Onglets de l'Index : chaque onglet prend le style de sa mutation
local tabs = need(StarterGui, "UI_Index_v3.Root.MutationTabs")
for id in UI_STYLES do
	local tab = tabs:FindFirstChild(id .. "Tab")
	if tab then
		for _, child in tab:GetChildren() do
			if child:IsA("UIGradient") then
				child:Destroy()
			end
		end
		local g = need(styles, id .. ".TagGradient"):Clone()
		g.Name = "UIGradient"
		g.Parent = tab
		local label = need(tab, "TabLabel") :: TextLabel
		label.TextColor3 = hex(UI_STYLES[id].Label)
		local labelStroke = label:FindFirstChildOfClass("UIStroke")
		if labelStroke then
			labelStroke.Color = hex(UI_STYLES[id].Stroke)
		end
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("Styles d'UI des mutations construits")

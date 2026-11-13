-- UI_ZoneBanner : aucun texte sur deux lignes, police du jeu (demande de Clément, 2026-11-13).
-- À lancer en Edit (barre de commande ou MCP). Annulable avec Ctrl+Z. Aucun script dans l'UI.
--
-- Règle mesurée dans Studio : TextScaled force TextWrapped, donc un texte avec une espace passe sur
-- deux lignes dès que deux lignes donnent un texte plus grand. Ça n'arrive jamais si la case est au
-- moins deux fois moins large que haute que le texte sur une ligne (largeur / hauteur >= A / 2, A =
-- largeur / hauteur du texte sur une ligne). Un mot seul ne se coupe jamais : il rapetisse.
--   « LOS ANGELES » A = 6,1 ; « FORTUNE TOWER » 7,9 ; « Strength 12.3B » 6,5 ; « Speed 48 » 4,2
--   (Montserrat Heavy). Les cases ci-dessous tiennent tous ces textes sur une ligne.
-- Mesuré de 1920 × 1080 à 568 × 320 : plus petit texte 13 px (« Recommended: »), chiffres 14 px et plus.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local recording = ChangeHistoryService:TryBeginRecording("ZoneBanner une ligne")

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

-- Enfant obligatoire : erreur claire s'il manque (script de construction, lancé à la main).
local function need(parent: Instance, name: string): any
	local child = parent:FindFirstChild(name)
	assert(child, name .. " introuvable dans " .. parent:GetFullName())
	return child
end

local gui = need(game:GetService("StarterGui"), "UI_ZoneBanner")
local banner = need(gui, "Banner") :: Frame
local advice = need(banner, "Advice") :: Frame

-- Police du jeu partout (ZoneName et Difficulty étaient en Luckiest Guy).
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") then
		d.FontFace = FONT
		d.TextScaled = true
		d.TextWrapped = true
	end
end

-- Ville : case de rapport 7,4 (0,92 × 3,4 / 0,42).
local zoneName = need(banner, "ZoneName") :: TextLabel
zoneName.Size = UDim2.fromScale(0.92, 0.42)
zoneName.Position = UDim2.fromScale(0.5, 0.03)

-- Ligne des conseils : rapport 12,1 (0,96 × 3,4 / 0,27).
advice.Size = UDim2.fromScale(0.96, 0.27)
advice.Position = UDim2.fromScale(0.5, 0.49)
local layout = need(advice, "UIListLayout") :: UIListLayout
layout.Padding = UDim.new(0.012, 0)
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local recommended = need(advice, "RecommendedLabel") :: TextLabel
recommended.Size = UDim2.fromScale(0.40, 0.72)
recommended.TextXAlignment = Enum.TextXAlignment.Right

for _, iconName in { "SpeedIcon", "DamageIcon" } do
	local icon = need(advice, iconName) :: ImageLabel
	icon.Size = UDim2.fromScale(1, 0.9)
end

-- Valeurs : rapport 3,45 (0,2 × 12,1 / 0,70), assez pour « Strength 12.3B » sur une ligne.
-- Le chiffre seul (« 28 », « 12.3B ») y prend toute la hauteur.
for _, valueName in { "Speed", "Damage" } do
	local value = need(advice, valueName) :: TextLabel
	value.Size = UDim2.fromScale(0.2, 0.70)
	value.TextXAlignment = Enum.TextXAlignment.Left
end

local difficulty = need(banner, "Difficulty") :: TextLabel
difficulty.Size = UDim2.fromScale(0.4, 0.2)
difficulty.Position = UDim2.fromScale(0.5, 0.78)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("UI_ZoneBanner : police Montserrat Heavy, textes sur une ligne")

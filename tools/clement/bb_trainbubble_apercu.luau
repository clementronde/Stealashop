-- Aperçu des bulles ×N pour Clément (chef UI, 26/11) : à lancer en Play, côté Client, perso sur son tapis.
-- Pose 7 copies de ReplicatedStorage/Assets/UI/BB_TrainBubble autour du joueur, en ligne devant la caméra :
--   _G.BubblePreview("A") : une seule couleur (bleu de la Vitesse), éclat or à partir de ×10 (ce que fait le code) ;
--   _G.BubblePreview("B") : une couleur par valeur, celles des raretés de Config/Rarities
--     (×2 Commun, ×3 Peu commun, ×4 Rare, ×5 Épique, ×7 Légendaire, ×10 Mythique, ×20 Secret arc-en-ciel).
-- Rien n'est enregistré : tout disparaît à l'arrêt du Play. Aucun script n'est posé dans le modèle.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local hex = Color3.fromHex

local VALUES = { 2, 3, 4, 5, 7, 10, 20 }
local RARITY = {
	[2] = hex("#B0B7C3"),
	[3] = hex("#2FE08F"),
	[4] = hex("#2F9BFF"),
	[5] = hex("#A855F7"),
	[7] = hex("#FFC21A"),
	[10] = hex("#FF3B5C"),
}
local RAINBOW = { hex("#FF3B3B"), hex("#FFC21A"), hex("#3BE15A"), hex("#2F9BFF"), hex("#A855F7") }

local function rainbow()
	local kp = {}
	for i, c in RAINBOW do
		table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), c))
	end
	return ColorSequence.new(kp)
end

local function tint(button, color)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.55)
	button.Fill.Color = ColorSequence.new(light, color)
	button.Ring.Color = Color3.new(color.R * 0.32, color.G * 0.32, color.B * 0.32)
end

_G.BubblePreview = function(mode)
	local folder = workspace:FindFirstChild("_PREVIEW_BULLES_CLAUDE")
	if folder then
		folder:Destroy()
	end
	if mode == nil then
		return
	end
	local player = Players.LocalPlayer
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	folder = Instance.new("Folder")
	folder.Name = "_PREVIEW_BULLES_CLAUDE"
	folder.Parent = workspace
	local model = RS.Assets.UI.BB_TrainBubble
	for i, n in VALUES do
		local gui = model:Clone()
		local button = gui.Button
		button.MultiplierLabel.Text = "×" .. n
		local shine = n >= 10
		if mode == "B" then
			shine = false
			if n == 20 then
				button.Fill.Color = rainbow()
				button.Fill.Rotation = 35
				button.Ring.Color = hex("#4A1A7A")
			else
				tint(button, RARITY[n])
			end
		end
		button.Shine.Visible = shine
		gui.Adornee = root
		-- screen_capture ne montre pas les billboards AlwaysOnTop : coupé sur les copies seulement
		gui.AlwaysOnTop = false
		-- en ligne sur l'axe X du monde, juste devant le tapis (cadrage vérifié sur PLOT_Shop_03, caméra du jeu)
		gui.StudsOffsetWorldSpace = Vector3.new((i - 4) * 2.3, 3.4 + ((i % 2 == 0) and 1.3 or 0), -3)
		gui.Parent = folder
	end
end

--!nonstrict
-- ui_grande_boutique.luau (Clément, 2026-11-18 : « UI plus grande », d'après la vidéo de référence E) : à lancer en Edit.
-- La boutique Robux (UI_RobuxShop_v2) passe de 57 % à 80 % de la hauteur de l'écran (leurs fenêtres font 78 à 83 %),
-- centrée. Le rapport de la fenêtre (1,706) ne change pas : tout le contenu grandit d'autant, titres, cases et prix
-- compris, sans rien déplacer à l'intérieur. Sur téléphone, au moins 512 × 300 px (environ 90 % de la hauteur).
-- Le bas de la fenêtre passe sur la barre du bas (UI_Hotbar, même DisplayOrder 5) : la boutique passe à 6 pour la
-- couvrir et prendre ses clics.
-- Les 4 décors pendus (Decor.Hang1 à Hang4) étaient placés par rapport à l'écran : en 16:9 la caisse pendue mordait
-- sur la fenêtre agrandie. Decor passe dans Root, et chaque décor est accroché au bord de la fenêtre (deux à gauche,
-- deux à droite, comme sur la maquette) ; sa ficelle monte jusqu'au haut de l'écran quelle que soit sa taille.
-- Aucun nom changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-18_UIGrande/UI_RobuxShop_v2. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local HEIGHT = 0.80 -- hauteur de la fenêtre (fraction de l'écran)
local WIDTH = 0.80 -- largeur maximale (ne limite que sur un écran 4:3)
local MIN = Vector2.new(512, 300)
local MAX = Vector2.new(1640, 961)

local rec = CHS:TryBeginRecording("UI : boutique Robux plus grande (80 % de la hauteur)")
local ok, err = pcall(function()
	local gui = SG.UI_RobuxShop_v2
	local backups = SS.MapBackups:FindFirstChild("2026-11-18_UIGrande")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-18_UIGrande"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild(gui.Name) then
		gui:Clone().Parent = backups
	end
	gui.DisplayOrder = 6 -- au-dessus de UI_Hotbar (5)
	local root = gui.Root
	root.Size = UDim2.fromScale(WIDTH, HEIGHT)
	root.Position = UDim2.fromScale(0.5, 0.5) -- le décalage de 30 px servait aux onglets, retirés
	local sc = root:FindFirstChildOfClass("UISizeConstraint")
	sc.MinSize, sc.MaxSize = MIN, MAX
	local ar = root:FindFirstChildOfClass("UIAspectRatioConstraint")
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	assert(math.abs(ar.AspectRatio - MIN.X / MIN.Y) < 0.01, "rapport de la fenêtre inattendu : " .. ar.AspectRatio)

	-- Décors pendus accrochés à la fenêtre. Chaque Hang devient le carré de son icône (ancré par le bas) ; la
	-- ficelle et le nœud gardent leur dessin et la ficelle est allongée vers le haut (hors écran).
	local decor = gui:FindFirstChild("Decor") or root:FindFirstChild("Decor")
	assert(decor, "Decor introuvable")
	if decor.Parent ~= root then
		decor.Parent = root
		decor.Size, decor.Position = UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)
		-- x et bas de l'icône en fraction de la fenêtre, largeur en fraction de sa largeur (mesuré en 16:9 :
		-- mêmes écarts aux bords que sur la maquette, au-dessus des colonnes de boutons du HUD).
		local PLACE = {
			Hang1 = { x = -0.16, bottom = 0.2125, w = 0.0937 },
			Hang2 = { x = -0.073, bottom = 0.0875, w = 0.0661 },
			Hang3 = { x = 1.0069, bottom = 0.146, w = 0.0744 },
			Hang4 = { x = 1.0923, bottom = 0.225, w = 0.0689 },
		}
		for name, p in PLACE do
			local hang = decor[name]
			local icon, str, knot = hang.Icon, hang.String, hang.Knot
			local iy, ih = icon.Position.Y.Scale, icon.Size.Y.Scale -- en hauteur de l'ancien cadre
			local function y(v)
				return (v - iy) / ih -- en hauteur d'icône
			end
			local strBottom = y(str.Position.Y.Scale + str.Size.Y.Scale)
			str.AnchorPoint = Vector2.new(0, 1)
			str.Position = UDim2.fromScale(str.Position.X.Scale, strBottom)
			str.Size = UDim2.fromScale(str.Size.X.Scale, 25)
			knot.Position = UDim2.fromScale(knot.Position.X.Scale, y(knot.Position.Y.Scale))
			knot.Size = UDim2.fromScale(knot.Size.X.Scale, knot.Size.Y.Scale / ih)
			icon.Position, icon.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
			hang:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio = 1
			hang.AnchorPoint = Vector2.new(0, 1)
			hang.Position = UDim2.fromScale(p.x, p.bottom)
			hang.Size = UDim2.fromScale(p.w, p.w * ar.AspectRatio)
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique Robux à 80 % de la hauteur, centrée, au moins 512 × 300 px"

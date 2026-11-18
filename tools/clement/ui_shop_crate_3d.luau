--!nonstrict
-- ui_shop_crate_3d.luau (Clément, 2026-11-18 : « je veux que la crate ne soit pas une image mais le modèle 3D qui bouge
-- un peu ») : dans UI_RobuxShop_v2, Crate.Preview (ViewportFrame) reçoit une copie du modèle BOX_Secret
-- (ReplicatedStorage/Assets/Boxes, la caisse noire à « ? » de l'icône) et sa caméra (Preview.Camera, CurrentCamera).
-- Preview passe dans Crate.Icon (taille de l'icône) : il suit la boucle de CrateLoop sur Icon (monte, descend, se
-- secoue et grossit) ; l'image de Icon devient invisible (ImageTransparency 1, image et IconAsset gardés).
-- Le balancement lent du modèle (caméra qui tourne de quelques degrés) est au code (liaison).
-- Le modèle a été remplacé le même jour par la caisse à tenons BOX_Shop_ExclusiveCrate (box_shop_exclusive_crate.luau,
-- à lancer après celui-ci) ; ce script garde le placement de Preview dans Icon.
-- Peut se relancer (le modèle et la caméra sont refaits), en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local YAW, PITCH, FOV = math.rad(-28), math.rad(24), 32

local rec = CHS:TryBeginRecording("UI : caisse de la boutique Robux en 3D (BOX_Secret dans Crate.Preview)")
local ok, err = pcall(function()
	local crate = SG.UI_RobuxShop_v2.Root.Window.List.Content.Crate
	local icon = crate.Icon
	local preview = crate:FindFirstChild("Preview", true)
	preview.Parent = icon
	preview.AnchorPoint = Vector2.zero
	preview.Position = UDim2.fromScale(0, 0)
	preview.Size = UDim2.fromScale(1, 1)
	preview.Rotation = 0
	preview.BackgroundTransparency = 1
	preview.ZIndex = icon.ZIndex
	preview.Ambient = Color3.fromRGB(170, 170, 185)
	preview.LightColor = Color3.new(1, 1, 1)
	preview.LightDirection = Vector3.new(-0.6, -1, -0.8)
	for _, c in preview:GetChildren() do
		c:Destroy()
	end

	local model = RS.Assets.Boxes.BOX_Secret:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot()) -- centre de la caisse à l'origine
	model.Parent = preview

	-- Arêtes arc-en-ciel comme l'icône ICON_BOX_Secret (retour de Clément : « elle est pas rainbow ») : dans cette
	-- copie seulement, la pièce Tint (arêtes d'une seule couleur, que le jeu anime en arc-en-ciel) est cachée et
	-- 12 arêtes néon fines la remplacent, une couleur par arête vue (face avant : gauche rouge, droite jaune, haut
	-- bleu, bas vert ; face de côté : violet). Face avant = côté de la marque « ? » (Mark).
	local tint = model:FindFirstChild("Tint", true)
	local mark = model:FindFirstChild("Mark", true)
	local front = if mark and mark.Position.Z > 0 then 1 else -1
	-- caméra devant la face avant et décalée vers X = side : la face de côté x = side·w passe à droite de l'écran
	-- (caméra tournée vers −front·Z : sa droite est X = front)
	local side = front
	if tint and tint:IsA("BasePart") then
		tint.Transparency = 1
		local edges = Instance.new("Model")
		edges.Name = "RainbowEdges"
		local c, s = tint.CFrame, tint.Size
		local w, h, d, t = s.X / 2, s.Y / 2, s.Z / 2, 0.07
		local RED, YELLOW, BLUE, GREEN, PURPLE = Color3.fromHex("ff3b3b"), Color3.fromHex("ffd23a"), Color3.fromHex("2fa8ff"), Color3.fromHex("3be15a"), Color3.fromHex("a855f7")
		local function edge(pos, sz, color)
			local p = Instance.new("Part")
			p.Name = "Edge"
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.Neon
			p.Color = color
			p.Size = sz
			p.CFrame = c * CFrame.new(pos)
			p.Parent = edges
		end
		local fz, bz = front * d, -front * d
		local sx, ox = side * w, -side * w
		-- verticales
		edge(Vector3.new(ox, 0, fz), Vector3.new(t, 2 * h + t, t), RED)
		edge(Vector3.new(sx, 0, fz), Vector3.new(t, 2 * h + t, t), YELLOW)
		edge(Vector3.new(sx, 0, bz), Vector3.new(t, 2 * h + t, t), PURPLE)
		edge(Vector3.new(ox, 0, bz), Vector3.new(t, 2 * h + t, t), RED)
		-- largeur (X)
		edge(Vector3.new(0, h, fz), Vector3.new(2 * w + t, t, t), BLUE)
		edge(Vector3.new(0, -h, fz), Vector3.new(2 * w + t, t, t), GREEN)
		edge(Vector3.new(0, h, bz), Vector3.new(2 * w + t, t, t), BLUE)
		edge(Vector3.new(0, -h, bz), Vector3.new(2 * w + t, t, t), GREEN)
		-- profondeur (Z)
		edge(Vector3.new(sx, h, 0), Vector3.new(t, t, 2 * d + t), PURPLE)
		edge(Vector3.new(sx, -h, 0), Vector3.new(t, t, 2 * d + t), GREEN)
		edge(Vector3.new(ox, h, 0), Vector3.new(t, t, 2 * d + t), BLUE)
		edge(Vector3.new(ox, -h, 0), Vector3.new(t, t, 2 * d + t), GREEN)
		edges.Parent = model
	end

	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.FieldOfView = FOV
	local radius = size.Magnitude / 2
	local distance = radius / math.sin(math.rad(FOV / 2)) * 1.02
	-- face avant du modèle vers −Z (règle des modèles : face avant vers la rue) : la caméra est devant, un peu à côté
	-- et au-dessus, comme l'icône
	local dir = Vector3.new(-side * math.sin(math.abs(YAW)) * math.cos(PITCH), math.sin(PITCH), front * math.cos(YAW) * math.cos(PITCH))
	dir = Vector3.new(side * math.abs(dir.X), dir.Y, dir.Z)
	camera.CFrame = CFrame.lookAt(dir * distance, Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera

	icon.ImageTransparency = 1
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "caisse en 3D"

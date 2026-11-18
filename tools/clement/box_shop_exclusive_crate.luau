--!nonstrict
-- box_shop_exclusive_crate.luau (Clément, 2026-11-18 : « fais une vraie caisse dans le style stud, comme Steal an Egg ou
-- Break and Steal an Egg ») : modèle BOX_Shop_ExclusiveCrate, la caisse exclusive de la boutique Robux, en Parts
-- avec la matière « Studs » (MaterialVariant de MaterialService, une tuile par stud, celle du Studded Egg Pack).
--   15 pièces (≈ 180 triangles ; avec les enfants obligatoires d'un colis : Tint, CarryAttachment, LabelPoint,
--   OutlineHighlight éteint, budget d'un colis : 300) ; 4,4 × 4 × 3,4 studs ; pivot en bas au centre ; face avant
--   (le « ? ») vers −Z. Corps violet nuit, socle vert, bandeau bleu, montants d'angle rouge, jaune, violet et orange
--   (les arêtes arc-en-ciel de l'icône ICON_BOX_Secret), couvercle à marche, « ? » blanc en pixels, fermoir doré.
--   Rangé dans ReplicatedStorage/Assets/UI ; une copie va dans UI_RobuxShop_v2…Crate.Icon.Preview (ViewportFrame) avec
--   sa caméra, à la place de la copie de BOX_Secret. Aucun script. Peut se relancer, en Edit. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local NAME = "BOX_Shop_ExclusiveCrate"
local YAW, PITCH, FOV = math.rad(-28), math.rad(22), 32

local function hex(h)
	return Color3.fromHex(h)
end

local function build()
	local model = Instance.new("Model")
	model.Name = NAME
	local function part(name, size, pos, color, studs)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.Plastic
		if studs ~= false then
			p.MaterialVariant = "Studs"
		end
		p.Color = color
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Parent = model
		return p
	end
	-- socle, corps, bandeau, couvercle
	local base = part("Base", Vector3.new(4.4, 0.4, 3.4), Vector3.new(0, 0.2, 0), hex("3be15a"))
	local body = part("Body", Vector3.new(4, 2.2, 3), Vector3.new(0, 1.5, 0), hex("231a52"))
	-- enfants obligatoires d'un colis (contrat 10.4, comme BOX_Secret)
	local carry = Instance.new("Attachment")
	carry.Name = "CarryAttachment"
	carry.Position = Vector3.new(0, 0, 0)
	carry.Parent = body
	local label = Instance.new("Attachment")
	label.Name = "LabelPoint"
	label.Position = Vector3.new(0, 3.2, 0)
	label.Parent = body
	-- le bandeau est la pièce Tint du contrat des colis (10.4) : le jeu peut l'animer en arc-en-ciel comme un colis Secret
	part("Tint", Vector3.new(4.4, 0.3, 3.4), Vector3.new(0, 2.75, 0), hex("2fa8ff"))
	part("Lid", Vector3.new(4.2, 0.7, 3.2), Vector3.new(0, 3.25, 0), hex("17112f"))
	part("LidTop", Vector3.new(3.4, 0.35, 2.4), Vector3.new(0, 3.775, 0), hex("2c2266"))
	-- montants d'angle (arêtes arc-en-ciel)
	-- vue de face (caméra en −Z), la droite de l'écran est −X : avant gauche rouge, avant droit jaune, arrière droit
	-- (face de côté vue) violet, arrière gauche orange
	local POSTS = {
		{ 2, -1.5, "ff3b3b" }, { -2, -1.5, "ffd23a" }, { -2, 1.5, "a855f7" }, { 2, 1.5, "ff9f1c" },
	}
	for i, p in POSTS do
		part("Post" .. i, Vector3.new(0.5, 2.2, 0.5), Vector3.new(p[1], 1.5, p[2]), hex(p[3]))
	end
	-- « ? » en pixels sur la face avant (pixel 0,36, 0,2 d'épaisseur)
	local px, z = 0.36, -1.5 - 0.1
	local white = hex("f4f1ff")
	local y0 = 1.5 - 2.5 * px -- 6 rangées centrées sur le corps
	part("Mark1", Vector3.new(3 * px, px, 0.2), Vector3.new(0, y0 + 5 * px, z), white, false)
	-- la colonne de droite du « ? » (vue de face) est en −X
	part("Mark2", Vector3.new(px, px, 0.2), Vector3.new(-px, y0 + 4 * px, z), white, false)
	part("Mark3", Vector3.new(2 * px, px, 0.2), Vector3.new(-px / 2, y0 + 3 * px, z), white, false)
	part("Mark4", Vector3.new(px, px, 0.2), Vector3.new(0, y0 + 2 * px, z), white, false)
	part("Mark5", Vector3.new(px, px, 0.2), Vector3.new(0, y0, z), white, false)
	-- fermoir doré au bord avant du couvercle
	part("Clasp", Vector3.new(0.8, 0.6, 0.25), Vector3.new(0, 3.05, -1.7), hex("ffc21a"))
	local hl = Instance.new("Highlight")
	hl.Name = "OutlineHighlight"
	hl.Enabled = false
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(0, 0, 0)
	hl.Parent = model
	model.PrimaryPart = base
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local rec = CHS:TryBeginRecording("Modèle : caisse exclusive à tenons pour la boutique Robux")
local ok, err = pcall(function()
	local assets = RS.Assets
	local ui = assets:FindFirstChild("UI")
	if not ui then
		ui = Instance.new("Folder")
		ui.Name = "UI"
		ui.Parent = assets
	end
	local old = ui:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local master = build()
	master.Parent = ui

	-- copie dans le ViewportFrame de la caisse
	local crate = SG.UI_RobuxShop_v2.Root.Window.List.Content.Crate
	local preview = crate:FindFirstChild("Preview", true)
	for _, c in preview:GetChildren() do
		c:Destroy()
	end
	local model = master:Clone()
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	model.Parent = preview
	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.FieldOfView = FOV
	local radius = size.Magnitude / 2
	local distance = radius / math.sin(math.rad(FOV / 2)) * 0.98
	-- face avant vers −Z : caméra devant (z < 0), décalée vers −X pour voir la face de côté à droite de l'écran
	local dir = Vector3.new(-math.sin(math.abs(YAW)) * math.cos(PITCH), math.sin(PITCH), -math.cos(YAW) * math.cos(PITCH))
	camera.CFrame = CFrame.lookAt(dir * distance, Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera
	preview.Ambient = Color3.fromRGB(175, 170, 190)
	preview.LightColor = Color3.new(1, 1, 1)
	preview.LightDirection = Vector3.new(-0.5, -1, 0.6)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BOX_Shop_ExclusiveCrate construit et posé dans la caisse de la boutique"

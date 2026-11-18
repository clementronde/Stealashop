--!nonstrict
-- box_shop_crate_import_setup.luau (Clément, 2026-11-18 : la caisse exclusive de Claude Design est retenue) : à lancer en
-- Edit juste après l'import de StealAShop-Art/Boxes/ExclusiveCrate/BOX_Shop_ExclusiveCrate.fbx (Importateur 3D, réglages
-- par défaut ; le modèle arrive dans Workspace sous le nom BOX_Shop_ExclusiveCrate).
--   1. Redresse le modèle si l'import l'a couché, et met la face avant (le « ? ») vers −Z.
--   2. Matières et couleurs de la planche v2 : corps violet #7B2CFF et couvercle magenta #B13CFF en Plastic avec la
--      MaterialVariant Studs ; or #FFC21A ; bandes Neon*, Tint, Mark et Keyhole en Neon ; cristaux translucides.
--   3. Rangement au contrat des colis (10.4), comme BOX_Secret : Lid (Model) → FlapL et FlapR (Models, chacun avec son
--      rabat Shell et son or Frame), Body (CarryAttachment, LabelPoint), Tint, OutlineHighlight éteint ; pivot en bas au
--      centre ; tout ancré, sans collision.
--   4. Remplace la caisse à tenons de ReplicatedStorage/Assets/UI (l'ancienne part dans ServerStorage/MapBackups/
--      2026-11-18_ShopFigma) et en pose une copie dans UI_RobuxShop_v2…Crate.Icon.Preview, avec sa caméra.
-- Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SG = game:GetService("StarterGui")

local NAME = "BOX_Shop_ExclusiveCrate"
local YAW, PITCH, FOV = math.rad(-28), math.rad(22), 32

local COLORS = {
	Body = "7b2cff", FlapL = "b13cff", FlapR = "b13cff",
	FrameBody = "ffc21a", FrameL = "ffc21a", FrameR = "ffc21a", Medallion = "ffc21a", Lock = "ffc21a",
	NeonRed = "ff3b3b", NeonOrange = "ff9f1c", NeonYellow = "ffe23b", NeonGreen = "3be15a", NeonBlue = "2fa8ff",
	NeonPurple = "a855f7", Tint = "ffffff", Mark = "ffffff", Keyhole = "ffffff",
	CrystalPink = "ff5fd2", CrystalCyan = "5ff3ff",
}
local STUDS = { Body = true, FlapL = true, FlapR = true }
local NEON = { NeonRed = true, NeonOrange = true, NeonYellow = true, NeonGreen = true, NeonBlue = true, NeonPurple = true, Tint = true, Mark = true, Keyhole = true }
local CRYSTAL = { CrystalPink = true, CrystalCyan = true }

local function parts(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			list[d.Name] = d
		end
	end
	return list
end

local function rotateAll(model, around, rotation)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = CFrame.new(around) * rotation * CFrame.new(-around) * p.CFrame
		end
	end
end

local rec = CHS:TryBeginRecording("Modèle : caisse exclusive de Claude Design rangée et posée dans la boutique")
local report = {}
local ok, err = pcall(function()
	local imported = workspace:FindFirstChild(NAME)
	assert(imported and imported:IsA("Model"), "Workspace." .. NAME .. " introuvable : importer le FBX d'abord")
	local p = parts(imported)
	assert(p.Body and p.FlapL and p.FlapR and p.Mark, "pièces manquantes dans l'import")

	-- 1. Redresser : le corps doit avoir son haut vers +Y.
	local body = p.Body
	local cf, size = imported:GetBoundingBox()
	local bottom = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	if body.CFrame.UpVector:Dot(Vector3.yAxis) < 0.9 then
		rotateAll(imported, bottom, body.CFrame.Rotation:Inverse())
		table.insert(report, "redressé")
	end
	-- face avant : le « ? » doit être côté −Z
	cf, size = imported:GetBoundingBox()
	if p.Mark.Position.Z > cf.Position.Z then
		rotateAll(imported, cf.Position, CFrame.Angles(0, math.pi, 0))
		table.insert(report, "tourné de 180°")
	end

	-- 2. Matières et couleurs.
	for name, part in p do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if COLORS[name] then
			part.Color = Color3.fromHex(COLORS[name])
		end
		if NEON[name] then
			part.Material = Enum.Material.Neon
		elseif STUDS[name] then
			part.Material = Enum.Material.Plastic
			part.MaterialVariant = "Studs"
		elseif CRYSTAL[name] then
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = 0.1
			part.Reflectance = 0.15
		else
			part.Material = Enum.Material.SmoothPlastic
		end
		local sa = part:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy() -- couleurs unies de la planche, pas de texture d'import
		end
	end

	-- 3. Rangement au contrat des colis.
	local model = Instance.new("Model")
	model.Name = NAME
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = model
	for _, side in { "L", "R" } do
		local flap = Instance.new("Model")
		flap.Name = "Flap" .. side
		local shell = p["Flap" .. side]
		shell.Name = "Shell"
		shell.Parent = flap
		local frame = p["Frame" .. side]
		if frame then
			frame.Name = "Frame"
			frame.Parent = flap
		end
		flap.PrimaryPart = shell
		flap.Parent = lid
	end
	for name, part in p do
		if part.Parent and part.Parent:IsDescendantOf(imported) or part.Parent == imported then
			part.Parent = model
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "OutlineHighlight"
	hl.Enabled = false
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(0, 0, 0)
	hl.Parent = model
	imported:Destroy()
	-- Pivot au centre du bas, SANS rotation (vu le 2026-11-18 : un PivotTo avec un PrimaryPart déjà posé laissait un
	-- quart de tour caché dans PivotOffset et couchait les copies). Les pièces sont remises droites, puis le modèle est
	-- posé bas au centre en (0, 0, 0) et le pivot du corps est fixé à cet endroit.
	local R = body.CFrame.Rotation:Inverse()
	local c0 = model:GetBoundingBox().Position
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = CFrame.new(c0) * R * CFrame.new(-c0) * part.CFrame
		end
	end
	local function aabb()
		local mn, mx = Vector3.one * 1e9, Vector3.one * -1e9
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local h = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
							mn = mn:Min(w)
							mx = mx:Max(w)
						end
					end
				end
			end
		end
		return mn, mx
	end
	local mn, mx = aabb()
	local shift = Vector3.new(-(mn.X + mx.X) / 2, -mn.Y, -(mn.Z + mx.Z) / 2)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = CFrame.new(shift) * part.CFrame
		end
	end
	if p.Mark.Position.Z > 0 then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = CFrame.Angles(0, math.pi, 0) * part.CFrame
			end
		end
		table.insert(report, "tourné de 180°")
	end
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse()
	mn, mx = aabb()
	local carry = Instance.new("Attachment")
	carry.Name = "CarryAttachment"
	carry.Parent = body
	carry.WorldPosition = Vector3.zero
	local label = Instance.new("Attachment")
	label.Name = "LabelPoint"
	label.Parent = body
	label.WorldPosition = Vector3.new(0, mx.Y + 0.6, 0)
	table.insert(report, string.format("taille %.2f × %.2f × %.2f", mx.X - mn.X, mx.Z - mn.Z, mx.Y - mn.Y))

	-- 4. Remplacer la caisse à tenons et la poser dans la boutique.
	local ui = RS.Assets.UI
	local old = ui:FindFirstChild(NAME)
	if old then
		local folder = SS.MapBackups:FindFirstChild("2026-11-18_ShopFigma")
		if folder and not folder:FindFirstChild(NAME .. "_Tenons") then
			old.Name = NAME .. "_Tenons"
			old.Parent = folder
		else
			old:Destroy()
		end
	end
	model.Parent = ui

	local preview = SG.UI_RobuxShop_v2.Root.Window.List.Content.Crate:FindFirstChild("Preview", true)
	for _, c in preview:GetChildren() do
		c:Destroy()
	end
	local copy = model:Clone()
	local csize = mx - mn
	copy:PivotTo(CFrame.new(0, -csize.Y / 2, 0))
	copy.Parent = preview
	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.FieldOfView = FOV
	local distance = (csize.Magnitude / 2) / math.sin(math.rad(FOV / 2)) * 0.98
	local dir = Vector3.new(-math.sin(math.abs(YAW)) * math.cos(PITCH), math.sin(PITCH), -math.cos(YAW) * math.cos(PITCH))
	camera.CFrame = CFrame.lookAt(dir * distance, Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "caisse de Claude Design rangée : " .. table.concat(report, ", ")

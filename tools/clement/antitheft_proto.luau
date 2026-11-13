-- Chaînes de l'antivol qui font le tour de l'objet (Clément, 2026-11-13). En Edit, sans Play.
-- Sert de modèle au code d'Ironix : la fonction wrap(item) est celle à reprendre pour un FloorItem
-- sous antivol. Pose aussi l'aperçu Workspace/_PREVIEW_AntiTheft (4 objets) sous _PREVIEW_Mutations.
--
-- Principe : deux boucles de chaîne croisées en X sur la face avant (−Z) de l'objet, qui passent par
-- les côtés et la face arrière. Chaque boucle est un rectangle arrondi dans un plan qui contient
-- l'axe de profondeur (Z) et une direction u de la face avant, tournée de ±WrapAngle × l'angle de la
-- diagonale. Le rectangle colle à la boîte de l'objet (marge d'un demi-maillon). Les maillons sont
-- alternés : à plat sur la surface, puis de chant. Le cadenas pend au croisement de la face avant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kitFound = ReplicatedStorage.Assets.FX:FindFirstChild("FX_AntiTheft")
assert(kitFound, "FX_AntiTheft introuvable : lancer antitheft_fx_build.luau d'abord")
local kit = kitFound :: Model
local linkFound = kit:FindFirstChild("Link")
local padlockFound = kit:FindFirstChild("Padlock")
assert(linkFound and padlockFound, "FX_AntiTheft doit contenir Link et Padlock")
local linkTemplate = linkFound :: BasePart
local padlockTemplate = padlockFound :: Model

-- Point d'un rectangle arrondi (demi-côtés a, b, rayon r) à l'abscisse curviligne s, en partant du
-- milieu du côté avant (0, −b) vers +x. Renvoie position, tangente et normale sortante (2D).
local function roundedRect(a: number, b: number, r: number, s: number): (Vector2, Vector2, Vector2)
	local sx, sy = a - r, b - r
	local quarter = math.pi * r / 2
	local segments = {
		{ kind = "line", len = sx, from = Vector2.new(0, -b), dir = Vector2.new(1, 0), out = Vector2.new(0, -1) },
		{ kind = "arc", len = quarter, center = Vector2.new(sx, -sy), start = -math.pi / 2 },
		{ kind = "line", len = 2 * sy, from = Vector2.new(a, -sy), dir = Vector2.new(0, 1), out = Vector2.new(1, 0) },
		{ kind = "arc", len = quarter, center = Vector2.new(sx, sy), start = 0 },
		{ kind = "line", len = 2 * sx, from = Vector2.new(sx, b), dir = Vector2.new(-1, 0), out = Vector2.new(0, 1) },
		{ kind = "arc", len = quarter, center = Vector2.new(-sx, sy), start = math.pi / 2 },
		{ kind = "line", len = 2 * sy, from = Vector2.new(-a, sy), dir = Vector2.new(0, -1), out = Vector2.new(-1, 0) },
		{ kind = "arc", len = quarter, center = Vector2.new(-sx, -sy), start = math.pi },
		{ kind = "line", len = sx, from = Vector2.new(-sx, -b), dir = Vector2.new(1, 0), out = Vector2.new(0, -1) },
	}
	for _, seg in segments do
		if s <= seg.len or seg == segments[#segments] then
			if seg.kind == "line" then
				return seg.from + seg.dir * s, seg.dir, seg.out
			else
				local angle = seg.start + s / r
				local out = Vector2.new(math.cos(angle), math.sin(angle))
				return seg.center + out * r, Vector2.new(-out.Y, out.X), out
			end
		end
		s -= seg.len
	end
	return Vector2.new(0, -b), Vector2.new(1, 0), Vector2.new(0, -1)
end

local function perimeter(a: number, b: number, r: number): number
	return 4 * (a - r) + 4 * (b - r) + 2 * math.pi * r
end

-- Entoure `item` de chaînes et d'un cadenas. Renvoie le Model ajouté (AntiTheftChains).
local function wrap(item: Model): Model
	local cf, size = item:GetBoundingBox()
	local fit = kit:GetAttribute("FitSize") :: number
	local k = math.sqrt(size.X * size.Y) / fit * 1.1
	local pitch0 = (kit:GetAttribute("LinkPitch") :: number) * k
	local width = (kit:GetAttribute("LinkWidth") :: number) * k
	local wrapAngle = kit:GetAttribute("WrapAngle") :: number
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

	local model = Instance.new("Model")
	model.Name = "AntiTheftChains"

	local diagonal = math.atan2(hy, hx)
	for loop, sign in { 1, -1 } do
		local theta = sign * diagonal * wrapAngle
		local u = Vector3.new(math.cos(theta), math.sin(theta), 0)
		-- distance du centre au bord de la face avant le long de u
		local reach = math.min(hx / math.max(math.abs(u.X), 1e-3), hy / math.max(math.abs(u.Y), 1e-3))
		local margin = width * 0.5 + 0.01 + (loop - 1) * width * 0.15
		local a = reach + margin
		local b = hz + margin
		local r = math.min(a, b) * 0.35
		local total = perimeter(a, b, r)
		local count = math.max(8, math.floor(total / pitch0 / 2) * 2) -- pair : l'alternance se referme
		local pitch = total / count
		local n = u:Cross(Vector3.zAxis).Unit -- normale du plan de la boucle
		for i = 0, count - 1 do
			local p2, t2, o2 = roundedRect(a, b, r, i * pitch)
			local pos = u * p2.X + Vector3.zAxis * p2.Y
			local t = (u * t2.X + Vector3.zAxis * t2.Y).Unit
			local o = (u * o2.X + Vector3.zAxis * o2.Y).Unit
			local xAxis = if i % 2 == 0 then o else n
			local yAxis = t:Cross(xAxis)
			local link = linkTemplate:Clone()
			link.Name = string.format("Link_%d_%02d", loop, i + 1)
			link.Size = linkTemplate.Size * k
			link.CFrame = cf * CFrame.fromMatrix(pos, xAxis, yAxis, t)
			link.Parent = model
		end
	end

	local padlock = padlockTemplate:Clone()
	padlock:ScaleTo(k)
	padlock:PivotTo(cf * CFrame.new(0, 0, -(hz + width * 0.6)))
	padlock.Parent = model
	model.Parent = item
	return model
end

-- Aperçu : 4 objets de formes différentes, sous la rangée des mutations.
local old = workspace:FindFirstChild("_PREVIEW_AntiTheft")
if old then
	old:Destroy()
end
local preview = Instance.new("Model")
preview.Name = "_PREVIEW_AntiTheft"
local row = workspace:FindFirstChild("_PREVIEW_Mutations")
local anchor = if row and row:FindFirstChild("01_Normal") then (row :: any)["01_Normal"]:GetPivot() else workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -20)
local base = anchor * CFrame.new(0, -3.6, 0)
local names = { "ITM_Z3_CarteGraphiqueEnOr", "ITM_Z6_StatueDeLaLiberte", "ITM_Z1_BoissonEnergisante", "ITM_Z3_Souris" }
for i, name in names do
	local source = ReplicatedStorage.Assets.Items:FindFirstChild(name)
	if source then
		local item = source:Clone()
		item:PivotTo(base * CFrame.new(-(i - 1) * 3.8 - 3, 0, 0))
		item.Parent = preview
		wrap(item)
	end
end
preview.Parent = workspace

_G.AntiTheftProto = { wrap = wrap }
print("Aperçu de l'antivol posé : Workspace/_PREVIEW_AntiTheft")

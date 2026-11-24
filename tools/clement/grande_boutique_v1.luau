--[[
	grande_boutique_v1.luau (Clément, 2026-11-24) : « les boutiques ne sont pas assez impressionnantes, le plafond est
	trop bas, elles ne sont pas assez larges, les objets sont trop serrés ». Validé sur l'aperçu
	Workspace/_APERCU_GrandeBoutique/Grande_64 (« Oui, applique »), avec une échelle au lieu de l'escalier.

	À lancer en Edit, après plot_shop_builder.luau, collect_pad_v3.luau et rarest_treadmill_v2.luau. Sauvegarde :
	ServerStorage/MapBackups/2026-11-24_GrandeBoutique.

	1. Gabarit PLOT_Shop, PLOT_Shop_Rayons et les 6 boutiques du hub :
	   - largeur 48 -> 64 : façade étirée (x 10,05 à 22,7 -> 10,05 à 30,7), côtés décalés de ±8 ;
	   - rez-de-chaussée 15,4 -> 22 de haut (y 1,4 à 15,4 étiré, au-dessus +6,6) ;
	   - 8 places (L-294), rangs tous les 10 studs : DisplaySlot_01/02 z -33, 03/04 -23, 05/06 -13, 07/08 -3,
	     socles en x ±24, plaques en x ±19,1. Les places 9 à 20 (plus lues par le code depuis L-294) sont décalées
	     de ±8 en x, z inchangé ;
	   - carreaux refaits sur 16 colonnes, tapis central de 22 de large, bandeau de la porte monté ;
	   - socle du plus rare +8 en x, tapis de course -8 en x.
	2. Floor_2 (L-294, attendu par ShopStageService) dans le gabarit, repris de l'aperçu : plancher (y 22,8 à 23,7)
	   avec une trémie de 4,4 × 3,2 au centre du fond, échelle (TrussPart invisible pour grimper), garde-corps,
	   cadre, vitres, toit, néons du rez-de-chaussée ; places DisplaySlot_31 à _38 (mêmes x, z qu'en bas, +23,4),
	   CollectPad_31 à _38 ; places bonus du gamepass DisplaySlot_21 à _24 et CollectPad_21 à _24 au milieu de l'étage.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local DX, DY = 8, 6.6
local FLOOR_UP = 23.4 -- dessus du plancher de l'étage (23,7) - sol (0,3)
local ROWS = { -33, -23, -13, -3 } -- rangs des places 1-2, 3-4, 5-6, 7-8
local STAND_X, PAD_X = 24, 19.1

local function f(x: number): number
	local a, s = math.abs(x), if x < 0 then -1 else 1
	if a <= 10.05 then return x end
	if a <= 22.7 then return s * (10.05 + (a - 10.05) * (20.65 / 12.65)) end
	return s * (a + DX)
end
local function g(y: number): number
	if y <= 1.4 then return y end
	if y <= 15.4 then return 1.4 + (y - 1.4) * (20.6 / 14) end
	return y + DY
end
-- place n (1 à 20) : x, z de son socle
local function slotXZ(n: number, oldZ: number): (number, number)
	local x = if n % 2 == 1 then -STAND_X else STAND_X
	if n <= 8 then return x, ROWS[math.ceil(n / 2)] end
	return x, oldZ
end

local function transform(M: Instance, pv: CFrame)
	local done: { [Instance]: boolean } = {}
	local function W(v: Vector3): Vector3 return pv:VectorToWorldSpace(v) end
	local function mark(i: Instance)
		done[i] = true
		for _, x in i:GetDescendants() do done[x] = true end
	end
	local function rigid(i: Instance, d: Vector3)
		if i:IsA("Model") then
			i:PivotTo(i:GetPivot() + d)
		else
			if i:IsA("BasePart") then i.CFrame += d end
			for _, x in i:GetDescendants() do if x:IsA("BasePart") then x.CFrame += d end end
		end
		mark(i)
	end
	-- 1. socles, plaques, places
	for _, d in M:GetDescendants() do
		if done[d] then continue end
		local num = tonumber(d.Name:match("^DisplayStand_(%d+)$") or d.Name:match("^CollectPad_(%d+)$") or "")
		if num and d:IsA("BasePart") then
			local lp = pv:PointToObjectSpace(d.Position)
			local sx, sz = slotXZ(num, lp.Z)
			local tx = if d.Name:match("^CollectPad") then (if sx < 0 then -PAD_X else PAD_X) else sx
			rigid(d, W(Vector3.new(tx - lp.X, 0, sz - lp.Z)))
		end
	end
	for _, d in M:GetDescendants() do
		local num = tonumber(d.Name:match("^DisplaySlot_(%d+)$") or "")
		if num and d:IsA("Attachment") and not done[d] then
			local lp = pv:PointToObjectSpace(d.WorldPosition)
			local sx, sz = slotXZ(num, lp.Z)
			d.WorldPosition = (pv * CFrame.new(sx, lp.Y, sz)).Position
			done[d] = true
			if d.Parent then done[d.Parent] = true end -- RayonAnchor : ne bouge plus, la place garde sa hauteur
		end
	end
	local rar = M:FindFirstChild("RarestDisplay")
	if rar then rigid(rar, W(Vector3.new(DX, 0, 0))) end
	local tm = M:FindFirstChild("Treadmill")
	if tm then rigid(tm, W(Vector3.new(-DX, 0, 0))) end
	-- 2. carreaux sur 16 colonnes
	local function retile(folder: Instance?, z0: number, rows: number)
		if not folder then return end
		local proto = folder:FindFirstChildWhichIsA("BasePart")
		if not proto then return end
		for _, t in folder:GetChildren() do if t ~= proto then t:Destroy() end end
		local nt = 0
		for ix = 0, 15 do
			for iz = 0, rows - 1 do
				if (ix + iz) % 2 == 0 then
					nt += 1
					local t = proto:Clone()
					t.Name = "Tile_" .. nt
					t.CFrame = pv * CFrame.new(-30 + 4 * ix, 0.31, z0 + 2 + 4 * iz)
					t.Parent = folder
				end
			end
		end
		proto:Destroy()
		mark(folder)
	end
	retile(M:FindFirstChild("FloorTiles"), -40, 12)
	local s2 = M:FindFirstChild("Stage_2")
	retile(s2 and s2:FindFirstChild("FloorTilesExt"), 8, 8)
	-- 3. porte : seul le bandeau monte
	local door = M:FindFirstChild("PlotDoor")
	if door then
		local h = door:FindFirstChild("Header", true)
		if h and h:IsA("BasePart") then
			local lc = pv:ToObjectSpace(h.CFrame)
			local b, t = lc.Y - h.Size.Y / 2, lc.Y + h.Size.Y / 2 + DY
			h.Size = Vector3.new(h.Size.X, t - b, h.Size.Z)
			h.CFrame = pv * CFrame.new(lc.X, (b + t) / 2, lc.Z) * lc.Rotation
		end
		local ht = door:FindFirstChild("HeaderTrim_T", true)
		if ht and ht:IsA("BasePart") then ht.CFrame += W(Vector3.new(0, DY, 0)) end
		mark(door)
	end
	-- 4. tapis central : 22 de large
	for _, rn in { "Runner", "RunnerExt" } do
		for _, R in M:GetDescendants() do
			if R.Name == rn and R:IsA("Model") then
				for _, p in R:GetChildren() do
					if p:IsA("BasePart") then
						local lc = pv:ToObjectSpace(p.CFrame)
						local z0, z1, y0, y1 = lc.Z - p.Size.Z / 2, lc.Z + p.Size.Z / 2, lc.Y - p.Size.Y / 2, lc.Y + p.Size.Y / 2
						local x0, x1
						if p.Name == "Carpet" then x0, x1 = -11, 11
						elseif p.Name == "Edge_L" then x0, x1 = -11.35, -11
						elseif p.Name == "Edge_R" then x0, x1 = 11, 11.35
						else x0, x1 = -11.35, 11.35 end
						p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
						p.CFrame = pv * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
					end
				end
				mark(R)
			end
		end
	end
	-- 5. le reste : étirement
	for _, p in M:GetDescendants() do
		if p:IsA("BasePart") and not done[p] then
			local lc = pv:ToObjectSpace(p.CFrame)
			local hs = p.Size / 2
			local ex = (lc.RightVector * hs.X):Abs() + (lc.UpVector * hs.Y):Abs() + (lc.LookVector * hs.Z):Abs()
			local c = lc.Position
			local x0, x1 = f(c.X - ex.X), f(c.X + ex.X)
			local y0, y1 = g(c.Y - ex.Y), g(c.Y + ex.Y)
			local axes = { lc.RightVector, lc.UpVector, lc.LookVector }
			local comps = { p.Size.X, p.Size.Y, p.Size.Z }
			local round = p:IsA("Part") and p.Shape ~= Enum.PartType.Block
			if not round and not p:IsA("MeshPart") and not p:IsA("TrussPart") then
				for k, wa in { Vector3.xAxis, Vector3.yAxis } do
					local lo, hi = if k == 1 then x0 else y0, if k == 1 then x1 else y1
					local olen = 2 * (if k == 1 then ex.X else ex.Y)
					if olen >= 1.2 then
						for i, a in axes do
							if math.abs(a:Dot(wa)) > 0.999 then comps[i] = comps[i] * (hi - lo) / olen end
						end
					end
				end
			end
			p.Size = Vector3.new(comps[1], comps[2], comps[3])
			p.CFrame = pv * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, c.Z) * lc.Rotation
		end
	end
end

-- Floor_2 dans le gabarit, repris de l'aperçu
local function buildFloor2(T: Model, rayons: Model): string
	local old = T:FindFirstChild("Floor_2")
	if old then old:Destroy() end
	local prev = workspace:FindFirstChild("_APERCU_GrandeBoutique")
	local G = prev and prev:FindFirstChild("Grande_64")
	local E = G and G:FindFirstChild("Etage")
	if not (G and E) then return "aperçu absent : Floor_2 non construit" end
	local gpv = (G :: Model):GetPivot()
	local F = Instance.new("Model")
	F.Name = "Floor_2"
	for _, n in { "Floor2_A", "Floor2_B", "Floor2_C", "Floor2_D", "Frame_Etage", "Pane_Etage_C", "Roof2", "Ladder", "HoleRail", "CeilingLights_RDC" } do
		local c = E:FindFirstChild(n)
		if c then
			local k = c:Clone()
			if k:IsA("Model") then k:PivotTo(gpv:ToObjectSpace(k:GetPivot())) else (k :: BasePart).CFrame = gpv:ToObjectSpace((k :: BasePart).CFrame) end
			k.Parent = F
		end
	end
	-- places 31 à 38 : copies des socles et plaques du bas (déjà au nouveau plan), un étage plus haut
	local up = Vector3.new(0, FLOOR_UP, 0)
	local fit = nil
	local slotY = nil
	for _, d in T:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "DisplaySlot_01" then fit = d:GetAttribute("FitSize"); slotY = d.WorldPosition.Y end
	end
	local function copyStand(stand: BasePart, n: number, at: Vector3?)
		local s = stand:Clone()
		s.Name = string.format("DisplayStand_%02d", n)
		for _, x in s:GetDescendants() do
			-- ni l'ancienne place ni les UnboxBench_xx (le contrat les veut uniques, ils restent en bas)
			if x:IsA("Attachment") and (x.Name:match("^DisplaySlot_") or x.Name:match("^UnboxBench_")) then x:Destroy() end
		end
		local d = if at then at - Vector3.new(stand.Position.X, 0, stand.Position.Z) else up
		s.CFrame += d
		for _, x in s:GetDescendants() do if x:IsA("BasePart") then x.CFrame += d end end
		local a = Instance.new("Attachment")
		a.Name = string.format("DisplaySlot_%02d", n)
		a.Parent = s
		a.WorldPosition = Vector3.new(s.Position.X, (slotY or 2.745) + FLOOR_UP, s.Position.Z)
		if fit then a:SetAttribute("FitSize", fit) end
		s.Parent = F
		return s
	end
	local function copyPad(pad: BasePart, n: number, at: Vector3?)
		local p = pad:Clone()
		p.Name = string.format("CollectPad_%02d", n)
		local d = if at then at - Vector3.new(pad.Position.X, 0, pad.Position.Z) else up
		p.CFrame += d
		for _, x in p:GetDescendants() do if x:IsA("BasePart") then x.CFrame += d end end
		p.Parent = F
		return p
	end
	local stands, pads = {}, {}
	for _, root in { T, rayons } do
		for _, d in root:GetDescendants() do
			local sn = tonumber(d.Name:match("^DisplayStand_(%d+)$") or "")
			local pn = tonumber(d.Name:match("^CollectPad_(%d+)$") or "")
			if sn and sn <= 8 and d:IsA("BasePart") then stands[sn] = d end
			if pn and pn <= 8 and d:IsA("BasePart") then pads[pn] = d end
		end
	end
	for n = 1, 8 do
		if stands[n] then copyStand(stands[n], 30 + n) end
		if pads[n] then copyPad(pads[n], 30 + n) end
	end
	-- places bonus 21 à 24 : deux îlots au milieu de l'étage, plaques vers l'allée
	local bonus = { { 21, -9, -30 }, { 22, 9, -30 }, { 23, -9, -16 }, { 24, 9, -16 } }
	for _, b in bonus do
		local n, x, z = b[1], b[2], b[3]
		local src = stands[if x < 0 then 1 else 2]
		local psrc = pads[if x < 0 then 1 else 2] -- même côté que son socle : le haut du texte vers le socle
		if src then copyStand(src, n, Vector3.new(x, FLOOR_UP, z)) end
		if psrc then copyPad(psrc, n, Vector3.new(if x < 0 then -4.5 else 4.5, FLOOR_UP, z)) end
	end
	local all = F:GetDescendants()
	table.insert(all, F)
	-- les règles d'affichage du rez-de-chaussée ne valent pas pour l'étage : Frame_Etage/Back_L1 venait de
	-- Stage_1/Frame/Back_L1 avec HideFromStage = 2, et le fond de l'étage disparaissait au niveau 2 (rien ne le
	-- remplace là-haut). Floor_2 garde seulement ses propres règles, posées sur Floor_2 lui-même.
	local GROUND_RULES = { "HideFromStage", "ShowFromWalls", "HideFromWalls", "ShowFromSkill" }
	for _, d in all do
		for _, tg in CS:GetTags(d) do CS:RemoveTag(d, tg) end
		if d:IsA("LuaSourceContainer") then d:Destroy() end
		if d ~= F then
			for _, at in GROUND_RULES do d:SetAttribute(at, nil) end
		end
	end
	F.Parent = T
	return "Floor_2 : " .. #F:GetDescendants() .. " éléments"
end

local plots = RS.Assets.Plots
local T, Rayons = plots.PLOT_Shop, plots.PLOT_Shop_Rayons
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-24_GrandeBoutique") then
	local fb = Instance.new("Folder")
	fb.Name = "2026-11-24_GrandeBoutique"
	T:Clone().Parent = fb
	Rayons:Clone().Parent = fb
	for _, s in workspace.Map.Hub.Shops:GetChildren() do
		if s:IsA("Model") then s:Clone().Parent = fb end
	end
	fb.Parent = backups
end
transform(T, CFrame.identity)
transform(Rayons, CFrame.identity)
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then transform(s, s:GetPivot()) end
end
local msg = buildFloor2(T, Rayons)
print("[grande_boutique_v1] " .. msg)
return msg

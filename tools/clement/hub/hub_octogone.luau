--[[
	hub_octogone.luau (Clément, 2026-11-24) : « la boutique 6 est plus proche de la sortie que la 3 ou la 4 » et
	« la roue est gênée par la boutique 6 ». Choix validé sur l'aperçu Workspace/_APERCU_HubArc :
	les 6 boutiques en demi-octogone devant la sortie, façades alignées, angles droits.

	1. Hub agrandi de 40 studs au nord et au sud : tout ce qui est au-delà de |z| 160 recule de 40, les grandes
	   pièces qui passent |z| 160 (sol, SafeZone…) s'allongent, et la bande de murs et de dalles de |z| 120 à 160
	   est recopiée pour combler. Murs de z ±230 à ±270, SafeZone jusqu'à z ±275.
	2. Boutiques (et leurs PlotSite) : façades tangentes à un cercle de 177 studs centré en (16 ; 0), juste devant la
	   sortie. 3 et 4 regardent la sortie de face, 2 et 5 à 45°, 1 et 6 à 90° (elles se font face).
	   Portes : 1 (−42 ; 177), 2 (−114,8 ; 119,5), 3 (−161 ; 40), symétriques pour 4, 5, 6.
	   Distance porte → sortie (26 ; 0) : 185 à 191 studs (avant : 146 à 198).
	3. Jardin : les décors qui tombent dans une boutique sont retirés.
	À lancer une seule fois en Edit (garde-fou : attribut HubOctogone sur Map.Hub).
	Sauvegarde : ServerStorage/MapBackups/2026-11-24_HubOctogone.
]]

local SS = game:GetService("ServerStorage")
local H = workspace.Map.Hub
if H:GetAttribute("HubOctogone") then
	return "déjà appliqué"
end

local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-24_HubOctogone") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-24_HubOctogone"
	H:Clone().Parent = f
	f.Parent = backups
end

-- 1. agrandissement en z
local ZC, DZ = 160, 40
local function zext(p: BasePart): number
	local cf, s = p.CFrame, p.Size
	return math.abs(cf.RightVector.Z) * s.X / 2 + math.abs(cf.UpVector.Z) * s.Y / 2 + math.abs(cf.LookVector.Z) * s.Z / 2
end
local function shift(u: Instance, dz: number)
	if u:IsA("Model") then
		u:PivotTo(u:GetPivot() + Vector3.new(0, 0, dz))
	elseif u:IsA("BasePart") then
		u.CFrame = u.CFrame + Vector3.new(0, 0, dz)
	end
end
local units = {}
local function unitize(inst: Instance)
	for _, c in inst:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(units, c)
		elseif c:IsA("Model") then
			local _, s = c:GetBoundingBox()
			if math.max(s.X, s.Z) < 40 then table.insert(units, c) else unitize(c) end
		elseif c:IsA("Folder") then
			unitize(c)
		end
	end
end
for _, k in { "Walls", "Ground", "Garden", "Ambiance", "Plaza" } do unitize(H[k]) end
for _, c in H.Zones:GetChildren() do
	if c.Name == "ENV_Hub_Leaderboard" then table.insert(units, c) end
end
table.insert(units, H.SafeZone)

local dup = 0
for _, u in units do
	if u:IsDescendantOf(H.Walls) or u:IsDescendantOf(H.Ambiance) then
		local z = if u:IsA("Model") then u:GetPivot().Z else (u :: BasePart).Position.Z
		if z > ZC - DZ and z <= ZC then
			local c = u:Clone(); c.Parent = u.Parent; shift(c, DZ); dup += 1
		elseif z < -(ZC - DZ) and z >= -ZC then
			local c = u:Clone(); c.Parent = u.Parent; shift(c, -DZ); dup += 1
		end
	end
end
local moved, stretched = 0, 0
for _, u in units do
	if u:IsA("BasePart") then
		local e = zext(u)
		local z = u.Position.Z
		local z0, z1 = z - e, z + e
		if e > 30 and ((z0 < ZC and z1 > ZC) or (z0 < -ZC and z1 > -ZC)) then
			local cf = u.CFrame
			local ax = { cf.RightVector, cf.UpVector, cf.LookVector }
			local bi, bv = 1, 0
			for i = 1, 3 do
				if math.abs(ax[i].Z) > bv then bv = math.abs(ax[i].Z); bi = i end
			end
			if bv > 0.99 then
				local n0 = if z0 < -ZC then z0 - DZ else z0
				local n1 = if z1 > ZC then z1 + DZ else z1
				local add = (n1 - n0) - (z1 - z0)
				local s = u.Size
				u.Size = if bi == 1 then s + Vector3.new(add, 0, 0) elseif bi == 2 then s + Vector3.new(0, add, 0) else s + Vector3.new(0, 0, add)
				u.CFrame = CFrame.new(u.Position.X, u.Position.Y, (n0 + n1) / 2) * cf.Rotation
				stretched += 1
			end
		elseif z > ZC then
			shift(u, DZ); moved += 1
		elseif z < -ZC then
			shift(u, -DZ); moved += 1
		end
	else
		local z = (u :: Model):GetPivot().Z
		if z > ZC then shift(u, DZ); moved += 1 elseif z < -ZC then shift(u, -DZ); moved += 1 end
	end
end
-- trou du mur ouest entre les tronçons z 145 et 170 (et son symétrique s'il existe)
local rw = RaycastParams.new()
rw.FilterType = Enum.RaycastFilterType.Include
rw.FilterDescendantsInstances = { H.Walls }
local filled = 0
for _, sign in { 1, -1 } do
	for z = 150, 165, 2.5 do
		if not workspace:Raycast(Vector3.new(-250, 3, sign * z), Vector3.new(-80, 0, 0), rw) then
			for _, p in H.Walls:GetDescendants() do
				if p:IsA("BasePart") and p.Position.X < -270 and p.Name:sub(1, 2) == "W_" and math.abs(p.Position.Z - sign * 145) < 4 then
					local q = p:Clone(); q.Parent = p.Parent; q.CFrame = q.CFrame + Vector3.new(0, 0, sign * 12.5); filled += 1
				end
			end
			break
		end
	end
end

-- 2. boutiques en demi-octogone
local cx, r, x1, t2, z3 = 16, 177, -42, -8, 40
local k = math.sqrt(0.5)
local doors = {
	{ Vector2.new(x1, r), 270 },
	{ Vector2.new(cx - r * k + t2 * k, r * k + t2 * k), 315 },
	{ Vector2.new(cx - r, z3), 0 },
	{ Vector2.new(cx - r, -z3), 0 },
	{ Vector2.new(cx - r * k + t2 * k, -(r * k + t2 * k)), 45 },
	{ Vector2.new(x1, -r), 90 },
}
for i, d in doors do
	local shop = H.Shops:FindFirstChild(string.format("PLOT_Shop_%02d", i)) :: Model
	local site = H.PlotSites:FindFirstChild("PlotSite_" .. i) :: Model?
	local oldPv = shop:GetPivot()
	local f = math.rad(d[2])
	local fv = Vector3.new(math.cos(f), 0, math.sin(f))
	local P = Vector3.new(d[1].X, oldPv.Y, d[1].Y) - fv * 40
	local newPv = CFrame.lookAt(P, P + fv)
	local rel = if site then oldPv:Inverse() * site:GetPivot() else nil
	shop:PivotTo(newPv)
	if site and rel then site:PivotTo(newPv * rel) end
end

-- 3. jardin dans les boutiques
local function corners(cf: CFrame, sx: number, sz: number)
	local t = {}
	for _, a in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local w = cf * Vector3.new(a[1] * sx / 2, 0, a[2] * sz / 2)
		table.insert(t, Vector2.new(w.X, w.Z))
	end
	return t
end
local function separated(A, B): boolean
	for _, Pg in { A, B } do
		for i = 1, 4 do
			local e = Pg[i % 4 + 1] - Pg[i]
			local n = Vector2.new(-e.Y, e.X)
			local a0, a1, b0, b1 = math.huge, -math.huge, math.huge, -math.huge
			for _, v in A do local dd = v:Dot(n); a0 = math.min(a0, dd); a1 = math.max(a1, dd) end
			for _, v in B do local dd = v:Dot(n); b0 = math.min(b0, dd); b1 = math.max(b1, dd) end
			if a1 < b0 or b1 < a0 then return true end
		end
	end
	return false
end
local S = {}
for i = 1, 6 do
	local shop = H.Shops:FindFirstChild(string.format("PLOT_Shop_%02d", i))
	if shop and shop:IsA("Model") then
		local cf, sz = shop:GetBoundingBox()
		S[i] = corners(cf, sz.X, sz.Z)
	end
end
local removed, seen, conflicts = 0, {}, {}
for _, root in { H.Garden, H.Plaza, H.Zones, H.Stalls, H.Walls } do
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.Parent and not seen[p] and p.Position.Y < 20 then
			local C = corners(p.CFrame, p.Size.X, p.Size.Z)
			for i = 1, 6 do
				if not separated(S[i], C) then
					if root ~= H.Garden and root ~= H.Plaza then
						table.insert(conflicts, p:GetFullName())
					elseif math.max(p.Size.X, p.Size.Z) > 40 then
						if p.Name:find("Bed") then p:Destroy(); removed += 1 else table.insert(conflicts, p:GetFullName()) end
					else
						local top: Instance = p
						local m = p.Parent
						while m and m ~= root and m:IsA("Model") do
							local _, ms = m:GetBoundingBox()
							if math.max(ms.X, ms.Z) < 40 then top = m; m = m.Parent else break end
						end
						for _, dd in top:GetDescendants() do seen[dd] = true end
						seen[top] = true
						top:Destroy()
						removed += 1
					end
					break
				end
			end
		end
	end
end

H:SetAttribute("HubOctogone", true)
local msg = string.format("[hub_octogone] unités %d, recopiées %d, déplacées %d, allongées %d, mur comblé %d, jardin retiré %d, conflits %d %s",
	#units, dup, moved, stretched, filled, removed, #conflicts, table.concat(conflicts, " | "))
print(msg)
return msg

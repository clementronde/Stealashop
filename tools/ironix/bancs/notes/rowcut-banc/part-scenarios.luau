
local function key(rel, size, cf)
	local function r(x) return math.floor(x * 1000 + 0.5) / 1000 end
	local p, l = cf.Position, cf.LookVector
	return string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", rel, r(size.X), r(size.Y), r(size.Z), r(p.X), r(p.Y), r(p.Z), r(l.X), r(l.Y), r(l.Z))
end
-- Pièces attendues dans les copies Stage_2..Stage_level avec RowCut : gardées telles quelles si leur bord arrière
-- est au plus à 0,05 au-delà du fond, pièces fines du fond avancées, le reste absent.
local function expectedRowCut(level, depth)
	local lines = {}
	local tp = template:GetPivot()
	for j = 2, level do
		local s = find(template, "Stage_" .. j)
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				local cf = tp:Inverse() * d.CFrame
				local z0, z1 = span(template, d)
				local rel = "Stage_" .. j .. "." .. string.sub(d:GetFullName(), #s:GetFullName() + 2)
				if depth == nil or z1 <= depth + 0.05 then
					table.insert(lines, key(rel, d.Size, cf))
				elseif 40 - z1 <= 4 and z0 >= 36 and z1 - z0 <= 2 then
					table.insert(lines, key(rel, d.Size, cf + Vector3.new(0, 0, depth - 40)))
				end
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local function actual(plot)
	local lines = {}
	local pp = plot:GetPivot()
	for _, c in plot:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Stage_(%d+)$") or "")
		if n and n >= 2 then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					local rel = c.Name .. "." .. string.sub(d:GetFullName(), #c:GetFullName() + 2)
					table.insert(lines, key(rel, d.Size, pp:Inverse() * d.CFrame))
				end
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local function firstDiff(a, b)
	local la, lb = string.split(a, "\n"), string.split(b, "\n")
	local seen = {}
	for _, l in lb do seen[l] = (seen[l] or 0) + 1 end
	for _, l in la do
		if (seen[l] or 0) == 0 then return "attendu absent : " .. l end
		seen[l] -= 1
	end
	for l, c in seen do
		if c > 0 then return "en trop : " .. l end
	end
	return ""
end

---------------------------------------------------------------- R1 sans RowCut : coupe d'a179 (filet)
print("\nR1 sans RowCut : la coupe d'a179 reste (Bob, 11 présentoirs)")
check(template:GetAttribute("RowCut") == nil, "gabarit sans attribut RowCut")
setCount(bob, 11)
PlotService.Assign(bob, plot2)
advance(0.1)
local d11 = expectedDepth(11)
check(near(plot2:GetAttribute("StageDepth"), d11), `fond {tostring(plot2:GetAttribute("StageDepth"))} (attendu {d11})`)
do
	local uncut = find(plot2, "Stage_3.Walls.Uncut_R")
	local z0, z1 = nil, nil
	if uncut then z0, z1 = span(plot2, uncut) end
	check(uncut ~= nil and near(z0, -39) and near(z1, d11), `pièce longue entière raccourcie au fond ({tostring(z0)}..{tostring(z1)})`)
	local over = find(plot2, "Stage_2.Deco.Touch_Over")
	check(over ~= nil, "petite pièce à cheval, centre devant : gardée (règle d'a179)")
end
PlotService.Release(bob)
advance(0.1)

---------------------------------------------------------------- R2 avec RowCut : garder ou retirer, rien de raccourci
print("\nR2 avec RowCut = true : présentoir par présentoir, de 4 à 20 (Alice)")
template:SetAttribute("RowCut", true)
setCount(alice, 4)
PlotService.Assign(alice, plot1)
advance(0)
for count = 4, 20 do
	setCount(alice, count)
	local depth = expectedDepth(count)
	local level = math.min(5, math.ceil(count / 4))
	local limit = depth or 40
	check(plot1:GetAttribute("StageLevel") == level and (depth ~= nil) == (plot1:GetAttribute("StageDepth") ~= nil) and near(plot1:GetAttribute("StageDepth") or 40, limit),
		`{count} : niveau {level}, fond {tostring(depth)}`)
	local want, got = expectedRowCut(level, depth), actual(plot1)
	check(want == got, `{count} : pièces gardées identiques au gabarit, fines du fond avancées, le reste retiré {firstDiff(want, got)}`)
	local beyond = {}
	for _, d in plot1:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local _, z1 = span(plot1, d)
			if z1 > limit + 0.05 then
				table.insert(beyond, d.Name)
			end
		end
	end
	check(#beyond == 0, `{count} : rien de visible au-delà du fond ({table.concat(beyond, ", ")})`)
	if level >= 2 then
		local _, b1 = span(plot1, find(plot1, "Stage_2.Barriers.Barrier_B"))
		check(near(b1, limit) and near(pointZ(plot1), limit - 2.4), `{count} : mur invisible du fond et point du panneau avancés ({b1}, {pointZ(plot1)})`)
	end
	if level >= 3 then
		check((find(plot1, "Stage_3.Walls.Uncut_R") ~= nil) == (depth == nil), `{count} : pièce non découpée retirée tant que la boutique n'est pas entière`)
	end
	if level >= 5 then
		local c0, c1 = span(plot1, find(plot1, "Stage_5.Cameras.Cam_BackL_Body"))
		check(near((c0 + c1) / 2, 37.3 + limit - 40), `{count} : caméra du fond avancée`)
	end
end

---------------------------------------------------------------- R3 tronçon pile sur le plan
print("\nR3 tronçons pile sur le plan z 4 (9 présentoirs)")
setCount(alice, 9)
check(near(plot1:GetAttribute("StageDepth"), 4), `fond 4 ({tostring(plot1:GetAttribute("StageDepth"))})`)
check(find(plot1, "Stage_2.Deco.Touch_Front") ~= nil and find(plot1, "Stage_2.Deco.Touch_Noise") ~= nil, "tronçon qui finit sur le plan (et à 0,03 près) : gardé")
check(find(plot1, "Stage_2.Deco.Touch_Back") == nil and find(plot1, "Stage_2.Deco.Touch_Over") == nil, "tronçon qui commence sur le plan, ou qui le dépasse de 0,1 : retiré")
do
	local n = 0
	for _, d in find(plot1, "Stage_2"):GetDescendants() do
		if d.Name == "PlotFloorExt" then
			local _, z1 = span(plot1, d)
			check(z1 <= 4 + 1e-3, `tronçon de sol gardé devant le fond ({z1})`)
			n += 1
		end
	end
	check(n == 3, `3 tronçons de sol (−16..−12, −12..−4, −4..4) : {n}`)
end

---------------------------------------------------------------- R4 boutique entière, gabarit intact
print("\nR4 boutique entière (19 et 20 présentoirs), gabarit intact")
setCount(alice, 19)
check(plot1:GetAttribute("StageDepth") == nil and actual(plot1) == expectedRowCut(5, nil), "19 présentoirs : tout montré, comme le gabarit")
setCount(alice, 20)
check(actual(plot1) == expectedRowCut(5, nil), "20 présentoirs : tout montré")
check(templateSignature() == templateBefore, "gabarit et visuels des rayons intacts")

summary()

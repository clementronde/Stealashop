-- Gabarit découpé comme Clément le fera (L-190 Q1) : chaque pièce qui traverse un fond est coupée aux plans
-- z −12, −4, 4, 8, 16, 24, 32 (40 = fond du gabarit), même nom, même parent. Pièces fines du fond entières.
local PLANES = { -12, -4, 4, 8, 16, 24, 32 }
local function cutBox(name, parent, frame, x0, y0, z0, x1, y1, z1)
	local cuts = { z0 }
	for _, z in PLANES do
		if z > z0 + 1e-6 and z < z1 - 1e-6 then
			table.insert(cuts, z)
		end
	end
	table.insert(cuts, z1)
	local out = {}
	for i = 1, #cuts - 1 do
		table.insert(out, box(name, parent, frame, x0, y0, cuts[i], x1, y1, cuts[i + 1]))
	end
	return out
end
do
	stage(template, 1, T)
	local s2 = stage(template, 2, T)
	for _, p in cutBox("PlotFloorExt", s2, T, -24, -0.6, -16, 24, 0.3, 40) do
		p:SetAttribute("Accent", true)
	end
	local murets = new("Model", "Murets_Sides", s2)
	cutBox("Muret_L", murets, T, -24, 0.3, -39, -23, 3.3, 40)
	box("Muret_B", murets, T, -23, 0.3, 39, 23, 3.3, 40)
	local barriers = new("Model", "Barriers", s2)
	for _, p in cutBox("Barrier_L", barriers, T, -24, 0.3, -40, -23.6, 30, 40) do
		p.Transparency = 1
	end
	box("Barrier_B", barriers, T, -24, 0.3, 39.6, 24, 30, 40).Transparency = 1
	-- Tronçons pile sur le plan z 4 (et à 0,03 près, bruit de Studio) : devant le fond 4 ; au-delà, retirés.
	local deco = new("Model", "Deco", s2)
	box("Touch_Front", deco, T, 10, 0.3, 0, 11, 1, 4)
	box("Touch_Noise", deco, T, 12, 0.3, 0, 13, 1, 4.03)
	box("Touch_Back", deco, T, 14, 0.3, 4, 15, 1, 6)
	box("Touch_Over", deco, T, 16, 0.3, 0, 17, 1, 4.1)
	local s3 = stage(template, 3, T)
	local walls = new("Model", "Walls", s3)
	cutBox("Wall_L", walls, T, -24, 0.3, -39, -23, 16.2, 40)
	box("Wall_B", walls, T, -23, 0.3, 39, 23, 16.2, 40)
	cutBox("InnerSkin_L", walls, T, -23, 0.3, -39, -22.9, 16.1, 39)
	box("InnerSkin_B", walls, T, -22.9, 0.3, 38.9, 22.9, 16.1, 39)
	-- Pièce longue laissée entière : raccourcie sans RowCut (coupe d'a179), retirée avec RowCut tant que la
	-- boutique n'est pas entière.
	box("Uncut_R", walls, T, 23, 0.3, -39, 24, 16.2, 40)
	local s4 = stage(template, 4, T)
	local roof = new("Model", "Roof", s4)
	cutBox("RoofSlab", roof, T, -24, 16.2, -40, 24, 17, 40)
	cutBox("Ceiling", roof, T, -22.9, 16.1, -39, 22.9, 16.2, 38.9)
	box("Parapet_B", roof, T, -24, 17, 39.4, 24, 18, 40)
	box("AC_2", roof, T, -2, 17, 20.4, 2, 19.2, 23.6)
	local s5 = stage(template, 5, T)
	local cams = new("Model", "Cameras", s5)
	part("Cam_BackL_Body", cams, T * CFrame.lookAt(Vector3.new(-22.1, 14.6, 37.3), Vector3.new(0, 2, 0)), Vector3.new(0.7, 0.7, 1.6))
	-- Visuels des rayons 2 à 5 (PLOT_Shop_Rayons, repère du gabarit) : socles et plaques.
	for r = 2, 5 do
		local R = new("Model", string.format("Rayon_%02d", r), store)
		R.WorldPivot = T
		for n = 4 * r - 3, 4 * r do
			local p = slotPos(n)
			box(string.format("DisplayStand_%02d", n), R, T, p.X - 2, 0.3, p.Z - 2, p.X + 2, 1.5, p.Z + 2)
			box(string.format("CollectPad_%02d", n), R, T, p.X * 11 / 16 - 1.6, 0.3, p.Z - 1.6, p.X * 11 / 16 + 1.6, 0.42, p.Z + 1.6)
		end
	end
end


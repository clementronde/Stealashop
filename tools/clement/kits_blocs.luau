--!nocheck
-- Kits de produits en blocs (chef Map, 27/11 : la Banque pese ~65 000 triangles a l'ecran, l'Electronique ~30 000, pour un
-- budget de 15 000 par interieur ; les cylindres et les boules coutent bien plus que des pave une fois fondus).
-- A lancer en Edit APRES le script de construction d'un kit (pieces encore separees) et AVANT tools/clement/kits_fusion.luau.
-- Remplace, dans les magasins de BLOCS, chaque Part ronde par des paves de meme couleur, meme matiere, meme place :
--   cylindre fin ou petit (diametre < 0,3 ou epaisseur < 0,08 : pieces de monnaie, rouleaux, tiges) -> un pave ;
--   cylindre plus gros (bocal, vase, tube)                                                   -> prisme a 8 faces (2 paves a 45 deg) ;
--   boule de 0,45 ou plus (sac, globe, bonbon)                                               -> 3 paves croises ;
--   petite boule                                                                              -> un cube.
-- Ordre : script de construction (kit_lib.luau + kit_produits_<zone>.luau, ou la sauvegarde d'avant fusion pour la Banque),
-- puis ce script, puis kits_fusion.luau. Fait le 27/11 sur Banque, Electronique, JeuxVideo, Confiserie et Antiquaire.
-- Meme nom de piece (le premier pave le garde ; les autres « <Nom>_B », « <Nom>_C »). Aucun script. Relancable.
local BLOCS = _G.KITS_BLOCS or { "Banque", "Electronique", "JeuxVideo", "Confiserie", "Antiquaire" }
local kits = game:GetService("ServerStorage").Previews.KITS
local function clone(src, name, size, cf)
	local b = Instance.new("Part")
	b.Name = name
	b.Shape = Enum.PartType.Block
	b.Size = size
	b.CFrame = cf
	b.Color = src.Color
	b.Material = src.Material
	b.MaterialVariant = src.MaterialVariant
	b.Reflectance = src.Reflectance
	b.Transparency = src.Transparency
	b.CastShadow = src.CastShadow
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
	b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	b.Parent = src.Parent
	return b
end
local lines = {}
for _, name in BLOCS do
	local st = kits:FindFirstChild(name)
	if not st then
		table.insert(lines, name .. " : absent")
		continue
	end
	local nc, nb, made = 0, 0, 0
	for _, d in st:GetDescendants() do
		if d:IsA("Part") and d.Shape ~= Enum.PartType.Block then
			local s, cf = d.Size, d.CFrame
			if d.Shape == Enum.PartType.Cylinder then
				nc += 1
				local len, dia = s.X, math.min(s.Y, s.Z)
				if dia < 0.3 or len < 0.08 then
					clone(d, d.Name, Vector3.new(len, dia * 0.88, dia * 0.88), cf)
					made += 1
				else
					local w = dia * 0.924
					clone(d, d.Name, Vector3.new(len, w, w), cf)
					clone(d, d.Name .. "_B", Vector3.new(len, w, w), cf * CFrame.Angles(math.rad(45), 0, 0))
					made += 2
				end
			elseif d.Shape == Enum.PartType.Ball then
				nb += 1
				local r = math.min(s.X, s.Y, s.Z)
				if r >= 0.45 then
					local t = r * 0.64
					clone(d, d.Name, Vector3.new(r, t, t), cf)
					clone(d, d.Name .. "_B", Vector3.new(t, r, t), cf)
					clone(d, d.Name .. "_C", Vector3.new(t, t, r), cf)
					made += 3
				else
					clone(d, d.Name, Vector3.new(r * 0.82, r * 0.82, r * 0.82), cf)
					made += 1
				end
			else
				continue -- coin (Wedge/CornerWedge) : laisse tel quel
			end
			d:Destroy()
		end
	end
	table.insert(lines, string.format("%s : %d cylindres et %d boules remplaces par %d paves", name, nc, nb, made))
end
return table.concat(lines, "\n")

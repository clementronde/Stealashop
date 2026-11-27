--!nocheck
-- Fusion des kits de produits (Chef de projet, 26/11 : le kit pose dans la Bijouterie fait passer l'interieur de 1 050 a
-- 6 500 pieces ; « une piece par produit, deux au plus pour la vitrine en verre » ; puis « laisse les flammes hors de
-- l'union, en piece Neon a part, comme le verre »). A lancer en Edit APRES les scripts de construction
-- (kit_produits_bijouterie.luau, kit_produits_z1.luau, _z5, _z6...). Pour chaque produit ENV_* de
-- ServerStorage/Previews/KITS/<Magasin> :
--   « Base »  : toutes les pieces opaques fondues en UNE UnionOperation (couleurs gardees : UsePartColor = false ;
--               plastique lisse, sans tenons) ; PrimaryPart, pivot inchange (en bas au centre) ;
--   « Glow »  : ce qui brille (Neon : flamme, ecran, LED), a part, une seule piece ;
--   « Glass » : le verre transparent (Transparency > 0,3), a part, une seule piece.
-- Meme nom, meme emprise. Aucun script. Un produit deja fondu est saute. Relancable.
local MAGASINS = { "Bijouterie", "Banque", "SalleDesCoffres", "GalerieDArt", "Antiquaire", "Superette", "Kiosque",
	"Confiserie", "MagasinDeJouets", "Electronique", "JeuxVideo", "Horlogerie" }

local kits = game:GetService("ServerStorage").Previews.KITS
local report = {}
local function unionInto(m, list, name, mat, usePart)
	local first = table.remove(list, 1)
	if #list == 0 then
		first.Name = name
		return first
	end
	local ok, u = pcall(function()
		return first:UnionAsync(list, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	end)
	if not ok or not u then
		table.insert(list, 1, first)
		return nil
	end
	u.Name = name
	u.UsePartColor = usePart
	if usePart then
		u.Color = first.Color
		u.Transparency = first.Transparency
	end
	if mat then
		u.Material = mat
	end
	u.Anchored, u.CanCollide, u.CanTouch, u.CanQuery = true, false, false, false
	u.Parent = m
	first:Destroy()
	for _, p in list do
		p:Destroy()
	end
	return u
end
for _, nom in MAGASINS do
	local folder = kits:FindFirstChild(nom)
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") then
				local pivot = m:GetPivot()
				local opaque, glass, glow = {}, {}, {}
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						if d.Transparency >= 1 then
							d:Destroy()
						elseif d.Material == Enum.Material.Neon then
							table.insert(glow, d)
						elseif d.Transparency > 0.3 then
							table.insert(glass, d)
						else
							table.insert(opaque, d)
						end
					end
				end
				if #opaque <= 1 then
					continue -- deja fondu
				end
				local u = unionInto(m, opaque, "Base", Enum.Material.SmoothPlastic, false)
				if not u then
					table.insert(report, m.Name .. " : union ratee")
					continue
				end
				u.MaterialVariant = ""
				u.Reflectance = 0.05
				if #glow > 0 then
					local g = unionInto(m, glow, "Glow", Enum.Material.Neon, true)
					if g then
						g.CastShadow = false
					end
				end
				if #glass > 0 then
					local g = unionInto(m, glass, "Glass", Enum.Material.Glass, true)
					if g then
						g.CastShadow = false
					end
				end
				u.PivotOffset = u.CFrame:Inverse() * pivot
				m.PrimaryPart = u
				local n = 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
					end
				end
				table.insert(report, string.format("%s : %d piece(s)", m.Name, n))
			end
		end
		task.wait()
	end
end
table.sort(report)
print("[kits fusion] " .. #report .. " produits fondus")
return table.concat(report, "\n")

--!nocheck
-- Habillage volontairement raté de Workspace/_PREVIEW_ALLEE_RATEE, pour la vidéo B du trailer (« une allée moche, puis
-- les belles »). Mots de Clément (27/11) : « des petites boutiques très mal faites, des petits lampadaires mal faits,
-- une route mal faite ». Comme un jeu fait trop vite : blocs d'une seule couleur terne, de travers, mal alignés,
-- fenêtres posées n'importe comment, lampadaires tordus, route d'un seul gris avec des bandes mal placées.
-- Aucun vrai modèle du jeu, aucun script, aucun tag, aucune lumière. Tout dans _PREVIEW_ALLEE_RATEE/Habillage.
-- L'allée : sol à y = 50, de x = 600 à 1438, murs à z = −2600 ± 60 ; la caméra passe au centre (z = −2600, y ≈ 55,5) :
-- rien n'est posé à moins de 14 studs du centre.
-- Graine fixe : relancer redonne la même allée. À retirer avec l'allée après le tournage.
-- À lancer dans Studio (MCP execute_luau, Edit).

local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromRGB
local root = workspace:FindFirstChild("_PREVIEW_ALLEE_RATEE")
assert(root, "_PREVIEW_ALLEE_RATEE introuvable")
local X0, X1, Y0, ZC = 600, 1438, 50, -2600
local rng = Random.new(1127)

local rec = CHS:TryBeginRecording("Allée ratée : habillage", { allowNoUndo = true })
local old = root:FindFirstChild("Habillage")
if old then old:Destroy() end
local H = Instance.new("Model")
H.Name = "Habillage"

local function block(name, cf, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = H
	return p
end

-- 1) Route d'un seul gris, un peu de travers, et des bandes blanches mal placées
local road = block("Road", CFrame.new((X0 + X1) / 2, Y0 + 0.05, ZC + 1.5) * CFrame.Angles(0, math.rad(0.4), 0), Vector3.new(X1 - X0 - 6, 0.1, 30), rgb(105, 105, 108))
local x = X0 + 12
local k = 0
while x < X1 - 20 do
	k += 1
	local len = rng:NextNumber(4, 13)
	local dz = rng:NextNumber(-3.5, 3.5)
	local yaw = math.rad(rng:NextNumber(-9, 9))
	block("Stripe_" .. k, CFrame.new(x + len / 2, Y0 + 0.12, ZC + dz) * CFrame.Angles(0, yaw, 0), Vector3.new(len, 0.05, rng:NextNumber(0.6, 1.4)), rgb(235, 235, 225))
	x += len + rng:NextNumber(3, 16)
end
-- deux trottoirs trop hauts et pas droits
for _, s in { -1, 1 } do
	local n = 0
	local xs = X0
	while xs < X1 do
		n += 1
		local len = rng:NextNumber(40, 90)
		local h = rng:NextNumber(0.6, 1.6)
		block("Kerb_" .. (s > 0 and "N" or "S") .. "_" .. n, CFrame.new(xs + len / 2, Y0 + h / 2, ZC + s * rng:NextNumber(17, 19.5)) * CFrame.Angles(0, math.rad(rng:NextNumber(-1.5, 1.5)), 0), Vector3.new(len, h, rng:NextNumber(2, 4)), rgb(150, 148, 140))
		xs += len - rng:NextNumber(-2, 3)
	end
end

-- 2) Petites boutiques très mal faites, des deux côtés
local DULL = { rgb(150, 150, 150), rgb(120, 120, 125), rgb(180, 170, 150), rgb(140, 155, 140), rgb(170, 140, 120), rgb(130, 140, 160) }
local shops = 0
for _, s in { -1, 1 } do
	local xs = X0 + rng:NextNumber(4, 20)
	while xs < X1 - 30 do
		shops += 1
		local w = rng:NextNumber(18, 34)
		local d = rng:NextNumber(14, 26)
		local h = rng:NextNumber(10, 24)
		local zFront = ZC + s * rng:NextNumber(24, 30) -- façade côté rue, jamais au centre
		local zc = zFront + s * d / 2
		local yaw = math.rad(rng:NextNumber(-8, 8))
		local cf = CFrame.new(xs + w / 2, Y0 + h / 2 + rng:NextNumber(-0.8, 0.6), zc) * CFrame.Angles(0, yaw, math.rad(rng:NextNumber(-2, 2)))
		local name = "Shop_" .. shops
		block(name, cf, Vector3.new(w, h, d), DULL[rng:NextInteger(1, #DULL)])
		-- toit plat posé de travers, qui dépasse d'un côté
		block(name .. "_Roof", cf * CFrame.new(rng:NextNumber(-2, 2), h / 2 + 0.4, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))), Vector3.new(w + rng:NextNumber(-1, 4), 0.8, d + rng:NextNumber(0, 3)), rgb(95, 95, 98))
		-- fenêtres n'importe comment : tailles et hauteurs au hasard, parfois qui dépassent du mur
		local nw = rng:NextInteger(1, 4)
		for i = 1, nw do
			local ww, wh = rng:NextNumber(2, 6), rng:NextNumber(2, 5)
			local lx = rng:NextNumber(-w / 2 + 1, w / 2 - 1)
			local ly = rng:NextNumber(-h / 2 + 2, h / 2 - 1.5)
			local out = -s * (d / 2 + rng:NextNumber(-0.05, 0.25))
			block(name .. "_Window_" .. i, cf * CFrame.new(lx, ly, out) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Vector3.new(ww, wh, 0.3), rgb(150, 190, 220))
		end
		-- porte brune, pas au milieu, parfois trop haute
		block(name .. "_Door", cf * CFrame.new(rng:NextNumber(-w / 3, w / 3), -h / 2 + 3 + rng:NextNumber(0, 1.2), -s * (d / 2 + 0.1)), Vector3.new(rng:NextNumber(3, 5), 6, 0.3), rgb(110, 80, 55))
		-- enseigne vide parfois, trop petite et penchée
		if rng:NextNumber() < 0.5 then
			block(name .. "_Sign", cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), h / 2 - 1.5, -s * (d / 2 + 0.25)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10))), Vector3.new(rng:NextNumber(4, 9), 1.4, 0.3), DULL[rng:NextInteger(1, #DULL)])
		end
		xs += w + rng:NextNumber(-2, 10) -- parfois collées, parfois qui se chevauchent un peu
	end
end

-- 3) Petits lampadaires tordus, sans lumière
local lamps = 0
for _, s in { -1, 1 } do
	local xl = X0 + rng:NextNumber(10, 30)
	while xl < X1 - 10 do
		lamps += 1
		local hgt = rng:NextNumber(7, 12)
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
		local base = CFrame.new(xl, Y0, ZC + s * rng:NextNumber(15, 17.5)) * tilt
		block("Lamp_" .. lamps .. "_Pole", base * CFrame.new(0, hgt / 2, 0), Vector3.new(0.6, hgt, 0.6), rgb(70, 70, 75))
		block("Lamp_" .. lamps .. "_Arm", base * CFrame.new(0, hgt - 0.3, -s * 1.2) * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0), Vector3.new(0.4, 0.4, rng:NextNumber(1.5, 3)), rgb(70, 70, 75))
		block("Lamp_" .. lamps .. "_Head", base * CFrame.new(rng:NextNumber(-0.4, 0.4), hgt - 0.6, -s * rng:NextNumber(1.8, 2.6)), Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.5, 1.2), rng:NextNumber(0.8, 1.6)), rgb(225, 215, 150))
		xl += rng:NextNumber(30, 70)
	end
end

H.Parent = root
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return ("Habillage : %d pièces (%d boutiques, %d lampadaires, %d bandes de route) ; centre de l'allée libre sur ±14"):format(#H:GetChildren(), shops, lamps, k)

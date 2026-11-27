--!nocheck
-- Plans bruts « inspi allées » (Clément, 26/11 ; brief-plans-inspi-allees.md) : 4 travellings rectilignes, sans montage,
-- sans personnage, sans HUD ni texte, 16:9 à 60 i/s, en Edit. À charger après trailer_lib.luau et shots_lancement.luau
-- (moteur image par image de la v5 : T.go, compteur, decouper_marque.py).
--   1. inspi_zones_tout : travelling latéral de la zone 1 à la zone 6, caméra tournée vers le sud (les façades sud),
--      qui glisse vers +x : à l'image, de gauche à droite ; inspi_zone1 … inspi_zone6 : la même prise, zone par zone.
--   2. inspi_z6_base : travelling avant, du bout de la zone 6 (x = 868) jusqu'à l'entrée du hub (x = -60).
--   3. inspi_allee_ratee : travelling avant dans Workspace/_PREVIEW_ALLEE_RATEE, de (600 ; 55,5 ; -2600) à (1438 ; 55,5 ; -2600).
--   4. inspi_notre_allee : même sens, même hauteur au-dessus du sol, même vitesse : de (30 ; 5,5 ; 0) à (868 ; 5,5 ; 0).
-- Vitesses constantes (aucun ralenti, aucune courbe) : LAT studs/s pour le plan 1, AV studs/s pour les plans 2 à 4.
-- FieldOfView 70 partout (brief). Avant chaque prise : témoins et personnages de la map cachés en local (L.hideHumans).
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def, "charger trailer_lib.luau puis shots_lancement.luau d'abord")
local V = Vector3.new
local LAT, AV, FOV = 25, 30, 70
L.INSPI = { LAT = LAT, AV = AV, FOV = FOV }

local function line(a: Vector3, b: Vector3, look: Vector3, speed: number)
	local dur = (b - a).Magnitude / speed
	return dur, function()
		return function(t)
			local u = math.clamp(t / dur, 0, 1)
			local p = a:Lerp(b, u)
			return p, p + look, FOV
		end
	end
end

-- personnages de la map (témoins, vendeurs, figurants) cachés le temps de la prise ; remis par T.stop
function L.hideHumans()
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then L.hide(d.Parent) end
	end
end

local function shot(name: string, a: Vector3, b: Vector3, look: Vector3, speed: number)
	local dur, cam = line(a, b, look, speed)
	for _, f in { "h" } do
		T.shots["L_" .. name .. "_" .. f] = { dur = dur, roll = false, cam = cam(), setup = function() L.hideHumans() end }
	end
	return dur
end

-- 1. latéral : caméra côté nord de la rue (z = +38), à 7 studs, tournée vers le sud, de la porte 1 au bout de la zone 6
local GATES = { 30, 118, 230, 368, 530, 718, 868 } -- ZoneGate_1 … ZoneGate_6, puis la façade de la Fortune Tower
local ZL, ZY, LOOKS = 38, 7, V(0, -0.05, -1)
L.INSPI.durs = {}
L.INSPI.durs.tout = shot("inspi_zones_tout", V(GATES[1], ZY, ZL), V(GATES[7], ZY, ZL), LOOKS, LAT)
for k = 1, 6 do
	L.INSPI.durs["zone" .. k] = shot("inspi_zone" .. k, V(GATES[k], ZY, ZL), V(GATES[k + 1], ZY, ZL), LOOKS, LAT)
end
-- 2. avant, du bout de la zone 6 vers la base (le hub, vers -x), au centre de la rue, hauteur d'yeux
L.INSPI.durs.base = shot("inspi_z6_base", V(866, 5.5, 0), V(-60, 5.5, 0), V(-1, 0, 0), AV)
-- 3. et 4. avant, même sens (+x), même hauteur au-dessus du sol (5,5), même vitesse
L.INSPI.durs.ratee = shot("inspi_allee_ratee", V(600, 55.5, -2600), V(1438, 55.5, -2600), V(1, 0, 0), AV)
L.INSPI.durs.notre = shot("inspi_notre_allee", V(30, 5.5, 0), V(868, 5.5, 0), V(1, 0, 0), AV)

-- 1 bis (v2, retour de Clément du 26/11 soir : façades trop basses, trop de route). Caméra rapprochée et montée, à
-- l'horizontale : façades sud à z = -47,7, caméra à z = 7 (55 studs), y = 20, FieldOfView 62 → la bande des magasins
-- (sol à 0, toits vers 40) va d'environ 20 % à 80 % de la hauteur, la route n'a plus que ~20 % du bas. 16 studs/s :
-- même vitesse apparente qu'avant (25 studs/s à 86 studs). Arrêt à x = 860 (le décor du bout, EndFacade, est à 866).
local LAT2, FOV2 = 16, 62
local function shotFov(name: string, a: Vector3, b: Vector3, look: Vector3, speed: number, fov: number)
	local dur = (b - a).Magnitude / speed
	T.shots["L_" .. name .. "_h"] = {
		dur = dur, roll = false, setup = function() L.hideHumans() end,
		cam = function(t)
			local p = a:Lerp(b, math.clamp(t / dur, 0, 1))
			return p, p + look, fov
		end,
	}
	return dur
end
local G2 = { 30, 118, 230, 368, 530, 718, 860 }
local Z2, Y2, LOOK2 = 7, 20, V(0, 0, -1)
L.INSPI.durs2 = {}
L.INSPI.durs2.tout = shotFov("inspi2_zones_tout", V(G2[1], Y2, Z2), V(G2[7], Y2, Z2), LOOK2, LAT2, FOV2)
for k = 1, 6 do
	L.INSPI.durs2["zone" .. k] = shotFov("inspi2_zone" .. k, V(G2[k], Y2, Z2), V(G2[k + 1], Y2, Z2), LOOK2, LAT2, FOV2)
end

local parts = {}
for k, d in L.INSPI.durs do table.insert(parts, ("%s %.1f s"):format(k, d)) end
table.sort(parts)
return "plans inspi : " .. table.concat(parts, ", ")

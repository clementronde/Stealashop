-- Tournage TikTok « la course des 6 zones » (2026-11-21, agent video-tiktok).
-- À lancer en PLAY dans Studio (place DEV), jamais en Edit : caméra, PlayerGui, vitesse de marche et position du
-- perso ne vivent que dans la session de test. Rien n'est créé dans StarterGui, Lighting ou la Map ; rien n'est
-- enregistré. ATTENTION : en Studio, le profil DEV est réellement sauvegardé (DataService) ; ce script ne fait que
-- courir et regarder (aucune casse, aucune ouverture, aucun achat).
--
-- Principe : ralenti ×4. Le perso court à sa vitesse de jeu / SLOW (l'animation de course standard de Roblox
-- ralentit avec la vitesse de marche), video_capture enregistre, le montage accélère ×4 : vraies images à 30 i/s.
-- video_capture s'arrête à 30 s : la course est tournée en 2 parties, raccordées à la porte de la zone 4, là où la
-- caméra change d'angle de toute façon.
--
-- Déroulé :
--   1. SERVEUR (au besoin) « chercher un Mythique » : nuits courtes (NightSkipTo, chaque tombée de la nuit remplit les
--      rayons) jusqu'à un colis BoxRarity = "Mythic" en zone 6, puis le jour.
--   2. CLIENT : ce morceau, avec PRISE = "R1" (hub → porte de la zone 4), "R2" (porte de la zone 4 → zone 6) ou
--      "F" (le colis Mythique sur son rayon).
--   3. SERVEUR « top » : workspace:SetAttribute("_ShootStart", workspace:GetServerTimeNow() + 1), pendant video_capture.
-- Le journal _G._shootLog note le temps (en s de vidéo) du passage de chaque porte, pour poser les titres au montage.

--[[CLIENT
local PRISE = "R1"
local SLOW = 4
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local ch = player.Character
local hum = ch:FindFirstChildOfClass("Humanoid")
local root = ch:FindFirstChild("HumanoidRootPart")
pcall(function() hum:UnequipTools() end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
_G._shootRunSpeed = _G._shootRunSpeed or hum.WalkSpeed -- vitesse de jeu, lue une fois
local SPEED = _G._shootRunSpeed / SLOW

-- Portes de zone (x) : Greybox.Corridor.Zone_<n>.ZoneGate_<n>
local GATES = { 30, 118, 230, 368, 530, 718 }
local function zoneOf(x)
	local z = 0
	for i, gx in GATES do if x >= gx then z = i end end
	return z
end

-- Angles de caméra, relatifs au perso (p) : { position, regard }
local function behind(p) return p + Vector3.new(-15, 8, 0), p + Vector3.new(30, 1, 0) end
local function sideL(p) return p + Vector3.new(9, 1.8, -14), p + Vector3.new(0, 3.2, 0) end
local function sideR(p) return p + Vector3.new(9, 1.8, 14), p + Vector3.new(0, 3.2, 0) end
local function front(p) return p + Vector3.new(15, 2.2, 3), p + Vector3.new(0, 3, 0) end
local function low(p) return p + Vector3.new(-9, 1.2, 4), p + Vector3.new(40, 7, 0) end
-- angle par zone : 0 = hub (accroche), 1 à 6 = zones
local BY_ZONE = { [0] = behind, behind, sideL, front, low, sideR, behind }
local DRONE_POS, DRONE_LOOK = Vector3.new(-20, 95, 0), Vector3.new(260, 0, 0)

local SHOTS = {
	R1 = { Start = Vector3.new(-55, 0, 0), StopX = 380, Drone = true }, -- deux persos du hub vers x = -84 et -77 : départ après eux
	R2 = { Start = Vector3.new(358, 0, 0), StopX = 805 },
}

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
-- Toute l'UI 2D (elle ne tourne pas avec la caméra) ; les panneaux flottants des magasins aussi, sauf pour la fin
-- (keepBoxes) où l'on garde l'étiquette du colis.
local function uiOff(keepBoxes)
	for _, g in player.PlayerGui:GetChildren() do
		if g.Enabled and (g:IsA("ScreenGui") or (g:IsA("BillboardGui") and not (keepBoxes and g.Name:find("Box", 1, true)))) then
			g.Enabled = false
		end
	end
end

-- La prise se change sans recoller ce morceau : _G._shootPrise = "R2" (client), puis un nouveau top.
_G._shootPrise = PRISE
_G._shootLog = {}
local lastPrise = nil
local placed = false
local lastZone = -1
local smoothP = nil

local function frame()
	local prise = _G._shootPrise
	local shot = SHOTS[prise]
	if prise ~= lastPrise then
		lastPrise, placed, lastZone, smoothP = prise, false, -1, nil
		_G._shootLog = {}
	end
	uiOff(prise == "F")
	local start = workspace:GetAttribute("_ShootStart")
	local t = if start then (workspace:GetServerTimeNow() - start) / SLOW else -1
	cam.CameraType = Enum.CameraType.Scriptable

	if shot then
		-- avant le top : posé au départ, tourné vers +x ; après : court vers +x, jusqu'à StopX
		if not placed then
			ch:PivotTo(CFrame.lookAt(shot.Start + Vector3.new(0, 3.2, 0), shot.Start + Vector3.new(100, 3.2, 0)))
			placed = true
		end
		hum.WalkSpeed = SPEED
		local x = root.Position.X
		if t >= 0 and x < shot.StopX then
			hum:Move(Vector3.new(1, 0, 0), false)
		else
			hum:Move(Vector3.zero, false)
		end
		local z = zoneOf(x)
		if z ~= lastZone then
			if t >= 0 then table.insert(_G._shootLog, string.format("zone %d à t=%.2f (x=%.1f)", z, t, x)) end
			lastZone = z
		end
		local p = root.Position
		smoothP = if smoothP then smoothP:Lerp(p, 0.35) else p
		local pos, look = BY_ZONE[z](smoothP)
		local cf = CFrame.lookAt(pos, look)
		if shot.Drone then
			-- accroche : drone au-dessus de l'entrée, qui plonge vers le dos du perso entre t = 0,1 et 1,0
			-- (la porte de la zone 1 passe vers 1,1 s)
			local u = smooth((t - 0.1) / 0.9)
			cf = CFrame.lookAt(DRONE_POS, DRONE_LOOK):Lerp(cf, u)
		end
		cam.FieldOfView = 55
		cam.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	else
		-- PRISE « F » : le colis Mythique sur son rayon (posé par _G._shootBox = Model du colis)
		-- _G._shootBox = Model du colis, _G._shootWinZ = z de la vitrine de son magasin (posés à part, côté client)
		local box = _G._shootBox
		local wz = _G._shootWinZ
		if box and box.Parent and wz then
			local c = box:GetPivot().Position
			local out = if c.Z > wz then -1 else 1 -- sens de la rue, vu depuis le colis
			local u = smooth(t / 3.6)
			local a = Vector3.new(c.X + 5, 7, wz + out * 16) -- dans la rue, derrière le perso
			local b = Vector3.new(c.X + 1, c.Y + 1.6, c.Z + out * 5.5) -- tout près du colis, à travers la vitre
			local pos = a:Lerp(b, u)
			cam.FieldOfView = 55 - 10 * u
			cam.CFrame = CFrame.lookAt(pos, c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
			-- le perso arrêté devant la vitrine, de dos, qui regarde le colis (à gauche du trajet de la caméra)
			if not placed then
				local at = Vector3.new(c.X - 2.5, 3.2, wz + out * 3)
				ch:PivotTo(CFrame.lookAt(at, Vector3.new(c.X - 2.5, 3.2, c.Z)))
				placed = true
			end
			hum.WalkSpeed = 0
			hum:Move(Vector3.zero, false)
		end
	end
end

pcall(function() RunService:UnbindFromRenderStep("_Shoot") end)
RunService:BindToRenderStep("_Shoot", Enum.RenderPriority.Last.Value + 100, frame)
return "client prêt : " .. PRISE .. ", vitesse de jeu " .. _G._shootRunSpeed .. " → " .. SPEED
CLIENT]]

--[[SERVER_FIND_MYTHIC
local CS = game:GetService("CollectionService")
local function scan()
	for _, b in CS:GetTagged("ShelfBox") do
		local slot = tostring(b:GetAttribute("SlotId"))
		if b:GetAttribute("BoxRarity") == "Mythic" and slot:find("STORE_Z6_", 1, true) then return b, slot end
	end
end
local box, slot = scan()
local tries = 0
while not box and tries < 9 do
	tries += 1
	workspace:SetAttribute("NightSkipTo", "Night 30")
	task.wait(2.2)
	box, slot = scan()
	workspace:SetAttribute("NightSkipTo", "Day 1800")
	task.wait(1.5)
end
return if box then ("Mythique : " .. slot .. " en " .. tostring(box:GetPivot().Position)) else "pas encore (relancer)"
SERVER_FIND_MYTHIC]]

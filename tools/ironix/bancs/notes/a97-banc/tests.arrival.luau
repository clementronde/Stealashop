--!nocheck
-- a97 (vague 29, L-105 point 2) : arrivée du camion en roulant, sur le faux Roblox et la mise en place du banc a27
-- (copie d'a51). Le camion du banc est livré debout (12,6 de large, 15,8 de haut, long en Z, pivot en bas au centre).
--   A. serveur : couché à sa place (Root debout), ArriveUpright, ArriveEndsAt, collisions coupées puis remises,
--      joueur resté dedans sorti par le côté, frappable comme avant ;
--   B. client : copie locale qui roule (départ à ArriveDistance), dérape, se couche, conducteurs éjectés,
--      vrai camion caché puis rendu (sans ses conducteurs), barre et contour ;
--   C. Explode et Leave pendant l'arrivée ; E. joueur qui reçoit le camion après l'arrivée ;
--   F. camion livré couché (conducteurs couchés) : pas rebasculé, pose debout sur l'arête de ses roues.

local TruckEvent = sharedModule("Config/TruckEvent")
local LANDING = TruckEvent.ArriveDriveTime + TruckEvent.ArriveSkidTime + TruckEvent.ArriveTipTime
local FINISH = LANDING + TruckEvent.ArriveSettleTime

-- Un conducteur debout dans la cabine du camion de base (le banc a27 n'en a pas).
local function addDriver(asset, name, position)
	local rig = make("Model", { Name = name })
	local hrp = make("Part", { Name = "HumanoidRootPart", Anchored = true, Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) }, rig)
	make("Part", { Name = "Torso", Anchored = true, Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position + Vector3.new(0, 2, 0)) }, rig)
	make("Humanoid", { Name = "Humanoid" }, rig)
	rig.PrimaryPart = hrp
	rig.Parent = asset
	return rig
end
addDriver(TRUCK_ASSET, "TruckDriver_01", Vector3.new(-3, 9, -14))
addDriver(TRUCK_ASSET, "TruckDriver_02", Vector3.new(3, 9, -14))

-- Coins (monde) des pièces de Pieces, transformés par `transform` (identité par défaut).
local function bodyCorners(model, transform)
	local out = {}
	for _, part in model:FindFirstChild("Pieces"):GetDescendants() do
		if part:IsA("BasePart") then
			local h = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = part.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
						table.insert(out, if transform then transform * corner else corner)
					end
				end
			end
		end
	end
	return out
end
local function extents(points)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in points do
		lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
		hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
	end
	return lo, hi
end
local function ghost()
	return Workspace:FindFirstChild("TruckArrival")
end
local function ejected()
	local out = {}
	for _, child in Workspace:GetChildren() do
		if child.Name == "TruckDriverEjected" then
			table.insert(out, child)
		end
	end
	return out
end
local function realHidden(model)
	local hidden, shown = 0, 0
	for _, part in model:FindFirstChild("Pieces"):GetDescendants() do
		if part:IsA("BasePart") then
			if part.LocalTransparencyModifier == 1 then
				hidden += 1
			else
				shown += 1
			end
		end
	end
	return hidden, shown
end
local function driverHidden(model)
	local all = true
	for _, name in { "TruckDriver_01", "TruckDriver_02" } do
		local rig = model:FindFirstChild(name)
		if rig == nil then
			return false
		end
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") and part.LocalTransparencyModifier ~= 1 then
				all = false
			end
		end
	end
	return all
end

startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(140, 3, 30), Vector3.new(0, 0, -1))
spawnCharacter(B, Vector3.new(140, 3, 2), Vector3.new(0, 0, -1)) -- là où le camion se couche
startClient(A)

section("A. Serveur")
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
local truck = currentTruck()
local final = truck:GetPivot()
local upright = truck:GetAttribute("ArriveUpright")
local spawnedAt = truck:GetAttribute("SpawnedAt")
check(type(upright) == "table" and getmetatable(upright).__type == "CFrame", "A1 ArriveUpright : une CFrame")
check(near(truck:GetAttribute("ArriveEndsAt") - spawnedAt, LANDING, 1e-6), `A2 ArriveEndsAt = SpawnedAt + {LANDING} s (impact au sol)`)
check(
	near(final.Position.X, 140, 1e-6) and near(final.Position.Y, 0, 1e-6) and math.abs(truck.PrimaryPart.CFrame.UpVector.Y) > 0.9999,
	"A3 Root reste debout sur son point (L-049, b)"
)
local lo, hi = extents(bodyCorners(truck))
check(
	near(hi.Y - lo.Y, 12.6, 1e-3) and near(hi.Z - lo.Z, 15.8, 1e-3) and near(lo.Y, 0, 1e-3) and near((lo.Z + hi.Z) / 2, 0, 1e-3),
	`A4 livré debout : couché, recentré, posé sur la route (haut {hi.Y - lo.Y}, large {hi.Z - lo.Z}, bas {lo.Y})`
)
check(logHas("livré debout : couché à sa place"), "A5 la sortie le dit (Studio)")
local hb = truck:FindFirstChild("HealthBarPoint", true)
check(hb and near(hb.WorldPosition.Y, 12.6 + 3.2, 1e-3) and near(hb.WorldPosition.Z, 0, 1e-3), `A6 barre de vie au-dessus de la caisse couchée ({hb and hb.WorldPosition})`)
local toUpright = (final * upright) * final:Inverse()
local ulo, uhi = extents(bodyCorners(truck, toUpright))
check(near(uhi.Y - ulo.Y, 15.8, 1e-3) and near(ulo.Y, 0, 1e-3), `A7 pose debout : 15,8 de haut, sur ses roues ({uhi.Y - ulo.Y}, bas {ulo.Y})`)
local collide, touch = 0, 0
for _, part in truck:GetDescendants() do
	if part:IsA("BasePart") then
		if part.CanCollide then
			collide += 1
		end
		if part.CanTouch then
			touch += 1
		end
	end
end
check(collide == 0 and touch == 0, `A8 pendant l'arrivée : aucune collision ni contact ({collide}, {touch})`)
check(type(truck:GetAttribute("WindowId")) == "string" and truck:GetAttribute("HP") == TruckEvent.MaxHP, "A9 frappable comme avant (cible posée tout de suite)")
local bobBefore = B.Character:GetPivot().Position
advance(FINISH - 0.1)
check((B.Character:GetPivot().Position - bobBefore).Magnitude < 1e-6, "A10 personne n'est poussé avant la fin de l'arrivée")
advance(0.2)
collide = 0
for _, part in truck:FindFirstChild("Pieces"):GetDescendants() do
	if part:IsA("BasePart") and part.CanCollide then
		collide += 1
	end
end
check(collide > 0, `A11 à la fin : collisions remises (pièces du bas, {collide})`)
local bob = B.Character:GetPivot().Position
check(math.abs(bob.Z) >= 7.9 + TruckEvent.ArrivePushMargin - 1e-3 and near(bob.X, 140, 1e-3), `A12 Bob, resté dedans, sorti par le flanc le plus proche ({bob})`)
check(near(bob.Y, 3, 1e-3), `A13 posé au sol (HumanoidRootPart à 3 studs, {bob.Y})`)
check((A.Character:GetPivot().Position - Vector3.new(140, 3, 30)).Magnitude < 1e-6, "A14 Alice, dehors, ne bouge pas")
check(logHas("sorti par le côté"), "A15 la sortie le dit (Studio)")

section("B. Client : copie qui roule, dérape et se couche")
Workspace:SetAttribute("TruckSpawnNow", 2) -- nouveau camion, Alice le voit arriver
flush()
truck = currentTruck()
final = truck:GetPivot()
upright = truck:GetAttribute("ArriveUpright")
local g = ghost()
check(g ~= nil and not hasTag(g, "EventTruck"), "B1 copie TruckArrival posée, sans le tag EventTruck")
local ok = g ~= nil
for _, part in (g and g:GetDescendants() or {}) do
	if part:IsA("BasePart") and (part.CanCollide or part.CanQuery or part.CanTouch or not part.Anchored) then
		ok = false
	end
end
check(ok, "B2 copie ancrée, sans collision, requête ni contact")
local hidden, shown = realHidden(truck)
check(hidden > 0 and shown == 0, `B3 vrai camion caché ({hidden} pièces)`)
local gui = A.PlayerGui:FindFirstChildWhichIsA("BillboardGui")
check(gui == nil or gui.Enabled == false, "B4 barre de vie cachée pendant l'arrivée")
local uprightWorld = final * upright
local speed = TruckEvent.ArriveDistance / (TruckEvent.ArriveDriveTime + TruckEvent.ArriveSkidTime / 2)
local d0 = g and (g:GetPivot().Position - uprightWorld.Position).Magnitude or -1
check(near(d0, TruckEvent.ArriveDistance, 0.01), `B5 départ à ArriveDistance studs de sa place ({d0})`)
local look = uprightWorld.LookVector
local behind = g and (uprightWorld.Position - g:GetPivot().Position).Unit or Vector3.zero
check(behind:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.999, "B6 il arrive par l'arrière, cabine devant, dans l'axe de la route")
check(g and g:GetPivot().UpVector:Dot(uprightWorld.UpVector) > 0.9999, "B7 debout pendant le roulage")
advance(1)
local d1 = (g:GetPivot().Position - uprightWorld.Position).Magnitude
check(near(d0 - d1, speed, 0.05), `B8 vitesse constante ({d0 - d1} studs en 1 s, {speed} attendus)`)
advance(TruckEvent.ArriveDriveTime + TruckEvent.ArriveSkidTime / 2 - 1)
local yawed = g:GetPivot().LookVector:Dot(uprightWorld.LookVector)
check(near(yawed, math.cos(TruckEvent.ArriveSwerveAngle), 0.01), `B9 l'arrière chasse au milieu du dérapage ({math.deg(math.acos(math.clamp(yawed, -1, 1)))}°)`)
advance(TruckEvent.ArriveSkidTime / 2)
local dSkid = (g:GetPivot().Position - uprightWorld.Position).Magnitude
check(dSkid < 0.2 and #ejected() == 0, `B10 arrêté à sa place, debout, conducteurs encore dedans ({dSkid})`)
advance(TruckEvent.ArriveTipTime * TruckEvent.DriverEjectAt + 0.05)
local out = ejected()
check(#out == 2, `B11 pendant la chute : les deux conducteurs éjectés ({#out})`)
check(g:FindFirstChild("TruckDriver_01") == nil, "B12 ils ont quitté la copie")
local flyY = #out > 0 and out[1]:GetPivot().Position.Y or 0
advance(0.15)
check(#out > 0 and out[1]:GetPivot().Position.Y > flyY, "B13 vol plané : ils montent")
local midLo = extents(bodyCorners(g))
check(midLo.Y > -1e-3 and midLo.Y < 0.5, `B13b en pleine chute : il pivote sur l'arête de ses roues, sans passer sous la route (bas {midLo.Y})`)
check(driverHidden(truck), "B14 conducteurs du vrai camion cachés")
advance(LANDING - (TruckEvent.ArriveDriveTime + TruckEvent.ArriveSkidTime + TruckEvent.ArriveTipTime * TruckEvent.DriverEjectAt + 0.2) + TruckEvent.ArriveSettleTime / 2)
local tilt = g.Parent and math.deg(math.acos(math.clamp(g:GetPivot().UpVector:Dot(final.UpVector), -1, 1))) or -1
check(g.Parent ~= nil and tilt > 0.5 and tilt <= math.deg(TruckEvent.ArriveSettleAngle) + 0.5, `B15 rebond après l'impact ({tilt}° de sa pose finale)`)
advance(TruckEvent.ArriveSettleTime / 2 + 0.1)
check(g.Parent == nil and ghost() == nil, "B16 fin : la copie disparaît")
hidden, shown = realHidden(truck)
check(hidden == 0 and shown > 0, "B17 le vrai camion revient")
check(driverHidden(truck), "B18 sans ses conducteurs (éjectés)")
gui = A.PlayerGui:FindFirstChildWhichIsA("BillboardGui")
check(gui ~= nil and gui.Enabled == true, "B19 barre de vie revenue")
local outline = truck:FindFirstChild("OutlineHighlight")
check(outline and outline.Enabled == true, "B20 contour revenu")
advance(TruckEvent.DriverLinger + TruckEvent.DriverFadeTime + 2)
check(#ejected() == 0, "B21 conducteurs éjectés : retombés, puis effacés")

section("C. Explode et Leave pendant l'arrivée")
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
truck = currentTruck()
advance(1)
check(ghost() ~= nil, "C1 arrivée en cours")
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
advance(0.1)
check(ghost() == nil, "C2 Explode : la copie disparaît")
check(driverHidden(truck), "C3 conducteurs toujours cachés (ils ne volent pas avec les pièces)")
advance(TruckEvent.RemoveDelay + 0.5)
Workspace:SetAttribute("TruckSpawnNow", 4)
flush()
advance(1)
check(ghost() ~= nil, "C4 nouvelle arrivée")
Workspace:SetAttribute("TruckSpawnNow", "Leave")
flush()
advance(0.1)
check(ghost() == nil and currentTruck() == nil, "C5 Leave : camion et copie partis")

section("E. Camion reçu après son arrivée")
Workspace:SetAttribute("TruckSpawnNow", 5)
flush()
truck = currentTruck()
advance(FINISH + 1)
CollectionService:RemoveTag(truck, "EventTruck")
flush()
CollectionService:AddTag(truck, "EventTruck")
flush()
check(ghost() == nil, "E1 pas de copie : il est déjà à sa place finale")
hidden, shown = realHidden(truck)
check(hidden == 0 and shown > 0 and driverHidden(truck), "E2 vu à sa place, sans ses conducteurs")

section("F. Camion livré couché")
-- Le modèle de base couché comme le serveur l'aurait fait (toit vers +X, recentré), Root debout.
local tipped = CFrame.new(-14.2, 0, 0) * CFrame.new(6.3, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(-6.3, 0, 0)
local assetPivot = TRUCK_ASSET:GetPivot()
local world = assetPivot * tipped * assetPivot:Inverse()
for _, d in TRUCK_ASSET:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "Root" then
		d.CFrame = world * d.CFrame
	elseif d:IsA("Model") and d.PrimaryPart == nil then
		d.WorldPivot = world * d.WorldPivot
	end
end
local templateLo, templateHi = extents(bodyCorners(TRUCK_ASSET, assetPivot:Inverse()))
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 6)
flush()
truck = currentTruck()
final = truck:GetPivot()
check(not logHas("livré debout"), "F1 pas rebasculé")
local flo, fhi = extents(bodyCorners(truck, final:Inverse()))
check((flo - templateLo).Magnitude < 1e-3 and (fhi - templateHi).Magnitude < 1e-3, "F2 pièces à la place du modèle")
upright = truck:GetAttribute("ArriveUpright")
toUpright = (final * upright) * final:Inverse()
ulo, uhi = extents(bodyCorners(truck, final:Inverse() * toUpright))
check(near(uhi.Y - ulo.Y, 15.8, 1e-3) and near(ulo.Y, 0, 1e-3), `F3 pose debout : 15,8 de haut, sur ses roues ({uhi.Y - ulo.Y}, bas {ulo.Y})`)
check(near(uhi.X, flo.X, 1e-3), `F4 redressé sur l'arête de ses roues (côté opposé au toit, x {uhi.X} = {flo.X})`)
advance(FINISH + 0.2)
check(ghost() == nil and #ejected() == 2, "F5 arrivée jouée, conducteurs éjectés")

summary("scénario arrivée (a97)")

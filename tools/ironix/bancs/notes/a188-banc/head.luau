--!nocheck
-- Compléments du banc a188 (pluie d'objets), lus après les en-têtes des bancs a103 et a109 et avant les tests :
-- bouchon de TelemetryService, vrai ItemRainService, rues « Street » de la carte, relevé des objets tombés.

---------------------------------------------------------------- bouchon de TelemetryService
TELEMETRY = {}
SOURCES["stub/TelemetryService"] = [==[
local TelemetryService = {}
function TelemetryService.LogEvent(player, key, fields, value)
	table.insert(TELEMETRY, { player = player, key = key, fields = fields or {}, value = value, t = os.clock() })
	return true
end
return TelemetryService
]==]
moduleScript(SERVICES, "TelemetryService", "stub/TelemetryService")
moduleScript(SERVICES, "ItemRainService", "server/Services/ItemRainService.luau")

function telemetry(key, player)
	local out = {}
	for _, e in TELEMETRY do
		if e.key == key and (player == nil or e.player == player) then
			table.insert(out, e)
		end
	end
	return out
end

---------------------------------------------------------------- carte : rues, arche, volume de zone
-- Magasins : zone 1 en x = 65 (mise en place a30), zone 2 en x = 140. Frontière des « magasins les plus proches » :
-- x = 102,5. Zone safe (hub) : x de −105 à 25 ; côté couloir (bouchon de NightCycleService) : x > 27.
ZONE_BORDER_X = 102.5
STREET_TOP = 0.2
function buildRainMap()
	STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)
	STORE_D = buildStore("STORE_Z2_Mode", 2, 140, -1)
	-- Rue de la zone 1 : x de 0 à 100 (elle entre dans la zone safe jusqu'à x = 25), z de −25 à 25.
	STREET_1 = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(100, 0.2, 50), CFrame = CFrame.new(50, 0.1, 0) }, MAP)
	-- Rue de la zone 2 : x de 100 à 200.
	STREET_2 = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(100, 0.2, 50), CFrame = CFrame.new(150, 0.1, 0) }, MAP)
	-- Une rue du même nom dans le hub, toute en zone safe : rien ne doit y tomber.
	STREET_HUB = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(60, 0.2, 50), CFrame = CFrame.new(-50, 0.1, 0) }, MAP)
	-- Arche en travers de la rue 2 (x de 148 à 152) : rien dessous ni à Clearance studs.
	ARCH = make("Part", { Name = "Arch", Anchored = true, Size = Vector3.new(4, 1, 60), CFrame = CFrame.new(150, 12, 0) }, MAP)
	-- Volume invisible au-dessus de toute la rue 2 (volume de zone) : les rayons le traversent.
	ZONE_VOLUME = make("Part", {
		Name = "ZoneVolume",
		Anchored = true,
		CanCollide = false,
		Transparency = 1,
		Size = Vector3.new(100, 30, 50),
		CFrame = CFrame.new(150, 15, 0),
	}, MAP)
end

---------------------------------------------------------------- démarrage
function startRain()
	startAll()
	Rain = serverModule("ItemRainService")
	IR = sharedModule("Config/ItemRain")
	LiveEvents = sharedModule("Config/LiveEvents")
	Night = serverModule("NightCycleService")
	-- Tirages vus : chaque appel de StoreHeistService.DrawForZone par la pluie (zone, contenu, chance).
	DRAWS = {}
	local realDraw = Heist.DrawForZone
	Heist.DrawForZone = function(zone)
		local content, luck = realDraw(zone)
		table.insert(DRAWS, { zone = zone, content = content, luck = luck })
		return content, luck
	end
end
-- Ce que fait EventService au début et à la fin d'un événement (attributs du Workspace).
function startEvent(duration)
	Workspace:SetAttribute(LiveEvents.EndsAtAttribute, Workspace:GetServerTimeNow() + (duration or LiveEvents.ById[IR.EventId].Duration))
	Workspace:SetAttribute(LiveEvents.IdAttribute, IR.EventId)
end
function stopEvent()
	Workspace:SetAttribute(LiveEvents.IdAttribute, nil)
	Workspace:SetAttribute(LiveEvents.EndsAtAttribute, nil)
end

---------------------------------------------------------------- relevé des objets tombés
-- RECORDS : un par objet de la pluie vu dans Workspace/CarryDrops, à l'image où il apparaît. onGround(rec) : encore
-- au sol, jamais ramassé. MAX_GROUND et MAX_NEW_PER_FRAME : relevés à chaque image.
RECORDS = {}
MAX_GROUND = 0
MAX_NEW_PER_FRAME = 0
local seenDrops = {}
local seenPayloads = {} -- un objet relâché puis retombé (nouveau dropId) n'est pas un nouvel objet de la pluie
function onGround(rec)
	return Carry.GetDrop(rec.id) == rec.payload
end
function groundCount()
	local n = 0
	for _, rec in RECORDS do
		if onGround(rec) then
			n += 1
		end
	end
	return n
end
function watchRain()
	ON_FRAME = function()
		local f = dropsFolder()
		local fresh = 0
		if f then
			for _, model in f:GetChildren() do
				local id = model:GetAttribute("DropId")
				if id and not seenDrops[id] then
					seenDrops[id] = true
					local payload, position = Carry.GetDrop(id)
					if payload and payload.StoreId == IR.StoreId and not seenPayloads[payload] then
						seenPayloads[payload] = true
						local nearest = math.huge
						for _, other in RECORDS do
							if onGround(other) then
								nearest = math.min(nearest, (other.position - position).Magnitude)
							end
						end
						fresh += 1
						table.insert(RECORDS, {
							id = id,
							model = model,
							payload = payload,
							position = position,
							t = now(),
							startY = model:GetPivot().Position.Y,
							lowestY = model:GetPivot().Position.Y,
							rose = false,
							nearest = nearest,
						})
					end
				end
			end
		end
		MAX_NEW_PER_FRAME = math.max(MAX_NEW_PER_FRAME, fresh)
		for _, rec in RECORDS do
			if rec.model.Parent ~= nil then
				local y = rec.model:GetPivot().Position.Y
				if y > rec.lowestY + 1e-6 then
					rec.rose = true -- un objet qui tombe ne remonte jamais
				end
				rec.lowestY = math.min(rec.lowestY, y)
			end
		end
		MAX_GROUND = math.max(MAX_GROUND, groundCount(), Rain.GetStats().OnGround)
	end
end
-- Zone attendue d'un point : celle des magasins les plus proches.
function zoneOfPoint(position)
	return if position.X < ZONE_BORDER_X then 1 else 2
end
-- Ramasse l'objet au sol `id` comme un client (GrabDropped au début et à la fin du maintien), debout à 2 studs.
function grabDrop(p, id)
	local _, position = Carry.GetDrop(id)
	moveTo(p, Vector3.new(position.X + 2, 3, position.Z))
	fireAs(p, "GrabDropped", id)
	advance(BatCfg.DroppedGrabTime + 0.05)
	fireAs(p, "GrabDropped", id)
	flush()
	return Carry.IsCarrying(p)
end

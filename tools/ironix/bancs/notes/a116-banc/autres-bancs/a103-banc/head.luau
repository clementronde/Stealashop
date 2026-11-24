--!nocheck
-- Compléments du banc a103 (L-112), lus après la mise en place du banc a30 (copie d'a66) et avant les
-- tests : Random de StoreHeistService piloté, bouchon de WitnessService, étiquettes BB_Box et BB_Carry,
-- outils des scénarios.

---------------------------------------------------------------- Random de StoreHeistService
-- HEIST_FORCED : prochaines valeurs de random:NextNumber() du seul StoreHeistService, dans l'ordre
-- (tirage de la chance, puis un tirage par cran de rareté). Vide : le Random déterministe du faux Roblox.
HEIST_FORCED = {}
do
	local realNew = Random.new
	Random = {
		new = function(seed)
			local r = realNew(seed)
			local source = debug.info(2, "s")
			if type(source) == "string" and string.find(source, "StoreHeistService", 1, true) then
				local original = r.NextNumber
				rawset(r, "NextNumber", function(self, a, b)
					if a == nil and #HEIST_FORCED > 0 then
						return table.remove(HEIST_FORCED, 1)
					end
					return original(self, a, b)
				end)
				HEIST_RANDOM = r
			end
			return r
		end,
	}
end

---------------------------------------------------------------- bouchon de WitnessService
SOURCES["stub/WitnessService"] = [==[
local W = { raised = {}, calmed = {}, calling = {}, listeners = {} }
function W.Raise(store, suspect, fillTime)
	table.insert(W.raised, { store = store, suspect = suspect, fillTime = fillTime, t = os.clock() })
	return true
end
function W.Calm(store)
	table.insert(W.calmed, { store = store, t = os.clock() })
	return true
end
function W.IsCalling(store) return W.calling[store] == true end
function W.OnCall(fn) table.insert(W.listeners, fn) return function() end end
function W._call(store, suspect)
	for _, fn in W.listeners do task.spawn(fn, store, suspect, nil) end
end
return W
]==]

---------------------------------------------------------------- étiquettes de Clément
-- BB_Box (Category, Rarity, Mutation) et BB_Carry (ItemName, Rarity, Income) : les tests y lisent la
-- rareté et la mutation d'un colis du rayon (jamais son objet) et ce que montre l'objet porté.
do
	local ui = folder(ASSETS, "UI")
	local box = make("BillboardGui", { Name = "BB_Box" }, ui)
	for _, n in { "Category", "Rarity", "Mutation" } do
		make("TextLabel", { Name = n, Text = "", Visible = true }, box)
	end
	local carry = make("BillboardGui", { Name = "BB_Carry" }, ui)
	for _, n in { "ItemName", "Rarity", "Income" } do
		make("TextLabel", { Name = n, Text = "", Visible = true }, carry)
	end
end

---------------------------------------------------------------- outils
function startAll(withoutWitness)
	if not withoutWitness then
		moduleScript(SERVICES, "WitnessService", "stub/WitnessService")
	end
	startServer()
	Carry = serverModule("CarryService")
	Heist = serverModule("StoreHeistService")
	WindowS = serverModule("WindowService")
	Witness = if withoutWitness then nil else serverModule("WitnessService")
	Balance = sharedModule("Config/Balance")
	Items = sharedModule("Config/Items")
	Rarities = sharedModule("Config/Rarities")
	Mutations = sharedModule("Config/Mutations")
	Formulas = sharedModule("Config/Formulas")
	SO = sharedModule("Config/ShelfOpen")
	SOS = sharedModule("ShelfOpenState")
	BatCfg = sharedModule("Config/Bat")
end
-- Joueur avec un DisplayName (annonce) et un personnage.
function player(name, position)
	local p = newPlayer(name)
	p.DisplayName = name
	spawnCharacter(p, position)
	return p
end
function slotName(n)
	return string.format("ShelfSlot_%02d", n)
end
function slotAttachment(store, n)
	return store:FindFirstChild(slotName(n), true)
end
local function shelfThing(store, n, tag)
	for _, m in shelfBoxes(store) do
		if m:GetAttribute("Slot") == slotName(n) and hasTag(m, tag) then
			return m
		end
	end
	return nil
end
-- Colis (tag ShelfBox) ou objet sorti (tag ShelfItem) du rayon `n`.
function boxAt(store, n)
	return shelfThing(store, n, "ShelfBox")
end
function itemAt(store, n)
	return shelfThing(store, n, "ShelfItem")
end
function itemCount(store)
	local c = 0
	for _, m in shelfBoxes(store) do
		if hasTag(m, "ShelfItem") then
			c += 1
		end
	end
	return c
end
function boxCount(store)
	local c = 0
	for _, m in shelfBoxes(store) do
		if hasTag(m, "ShelfBox") then
			c += 1
		end
	end
	return c
end
-- Debout devant le rayon `n`, à `back` studs (défaut 3), dans le volume Bounds.
function standAt(p, store, n, back)
	local pos = slotAttachment(store, n).WorldPosition
	local side = if pos.Z > 0 then -1 else 1
	moveTo(p, Vector3.new(pos.X, 3, pos.Z + side * (back or 3)), Vector3.new(0, 0, -side))
end
-- Valeur de NextNumber qui tire `luck` dans la table chargée (milieu de son intervalle).
function luckRoll(luck)
	local total, before, weight = 0, nil, nil
	for _, e in SO.LuckTable do
		if e.Luck == luck and before == nil then
			before, weight = total, e.Weight
		end
		total += e.Weight
	end
	assert(before, "chance absente de Config/ShelfOpen.LuckTable : " .. tostring(luck))
	return (before + weight / 2) / total
end
function luckValues()
	local list = {}
	for _, e in SO.LuckTable do
		table.insert(list, e.Luck)
	end
	table.sort(list)
	return list
end
-- Débit du remote (5/s) : au moins 0,25 s entre deux OpenShelfBox du même joueur.
local lastOpen = {}
-- a116 (2026-11-13, Cantin : rester appuyé sur E pour ouvrir) : OpenShelfBox au début puis à la fin du
-- maintien, séparés de `hold` s (défaut : GrabTime du type du colis + 0,05 s ; colis introuvable : 0).
function openHoldTime(slotId)
	for _, m in CollectionService:GetTagged("ShelfBox") do
		if m:GetAttribute("SlotId") == slotId then
			local info = Balance.Heist.BoxTiers[m:GetAttribute("Tier")]
			return if info then info.GrabTime + 0.05 else 0
		end
	end
	return 0
end
function fireOpen(p, slotId, hold)
	local last = lastOpen[p]
	if last and now() - last < 0.25 then
		advance(0.25 - (now() - last))
	end
	local wait = hold or openHoldTime(slotId)
	-- Valeurs forcées du Random gardées pour le lancement (fin du maintien) : rien ne les consomme pendant l'attente.
	local forced = table.clone(HEIST_FORCED)
	table.clear(HEIST_FORCED)
	fireAs(p, "OpenShelfBox", slotId) -- début du maintien
	if wait > 0 then
		advance(wait)
	end
	for _, v in forced do
		table.insert(HEIST_FORCED, v)
	end
	lastOpen[p] = now()
	fireAs(p, "OpenShelfBox", slotId) -- fin du maintien
	flush()
end
-- `p` se place devant le rayon `n` et lance l'ouverture du colis, avec la chance `luck` si elle est
-- donnée. Renvoie le colis (ouvert ou non : lire son attribut ShelfOpenState).
function openBox(p, store, n, luck)
	standAt(p, store, n)
	local box = boxAt(store, n)
	if box == nil then
		return nil
	end
	if luck then
		table.insert(HEIST_FORCED, luckRoll(luck))
	end
	fireOpen(p, box:GetAttribute("SlotId"))
	table.clear(HEIST_FORCED)
	return box
end
function isOpening(box)
	return box ~= nil and box:GetAttribute("ShelfOpenState") == "Opening"
end
-- Prise de l'objet sorti du rayon `n` : maintien du type du colis d'origine. true s'il le porte.
function takeItem(p, store, n, hold)
	standAt(p, store, n)
	local item = itemAt(store, n)
	if item == nil then
		return false
	end
	local grabTime = Balance.Heist.BoxTiers[item:GetAttribute("Tier")].GrabTime
	local slotId = item:GetAttribute("SlotId")
	fireAs(p, "GrabItem", slotId)
	advance(hold or (grabTime + 0.05))
	fireAs(p, "GrabItem", slotId)
	flush()
	return Carry.IsCarrying(p)
end
-- Casse la vitrine jusqu'à l'ouverture du magasin (une vitrine de zone 2 demande plusieurs coups).
function breakHard(p, store)
	local window = store:FindFirstChild("Window")
	equipCasse(p)
	local pos = window.Position
	local side = if pos.Z > 0 then -1 else 1
	moveTo(p, Vector3.new(pos.X, 3, pos.Z + side * 3), Vector3.new(0, 0, -side))
	for _ = 1, 60 do
		if store:GetAttribute("HeistOpen") == true then
			return true
		end
		fireAs(p, "HitWindow", window:GetAttribute("WindowId"))
		advance(0.4)
	end
	return store:GetAttribute("HeistOpen") == true
end
-- Magasin ouvert par `p` (son casseur : pas d'avance à attendre) ; reconstruit d'abord s'il est fermé.
function reopen(p, store)
	if store:GetAttribute("HeistOpen") == true then
		return
	end
	local window = store:FindFirstChild("Window")
	if window:GetAttribute("Broken") == true then
		WindowS.Rebuild(window:GetAttribute("WindowId"))
		flush()
	end
	assert(breakHard(p, store), "vitrine pas cassée : " .. store.Name)
end
-- Rareté (Id) et mutation (texte de BB_Box, nil sans mutation) d'un colis du rayon, lues sur son étiquette.
-- Copie a109 (vague 32) : la rareté est celle de la caisse ; la mutation n'y est plus jamais (nil).
function boxLabel(box)
	local gui = box:FindFirstChild("BB_Box", true)
	local rarityText = gui and gui:FindFirstChild("Rarity", true).Text
	local rarityId = nil
	for _, r in Rarities.List do
		if r.DisplayNameUpper == rarityText then
			rarityId = r.Id
		end
	end
	local mutation = gui and gui:FindFirstChild("Mutation", true)
	local mutationText = if mutation and mutation.Visible and mutation.Text ~= "" then mutation.Text else nil
	return rarityId, mutationText
end
-- Mutation de l'objet sorti, en texte d'étiquette (comme BB_Box), d'après ses attributs.
function itemMutationText(item)
	local size, effect = item:GetAttribute("MutationSize"), item:GetAttribute("MutationEffect")
	if size == nil and effect == nil then
		return nil
	end
	return Mutations.Label({ Size = size, Effect = effect })
end
-- Ouvre le colis du rayon `n` avec la chance `luck`, puis force les tirages de la sortie (copie a109,
-- vague 32 : `rolls` = prochains NextNumber à la sortie ; le premier tire la rareté de l'objet dans la table de
-- la caisse, 0 = la plus basse de la table, 1 - 1e-9 = la plus haute ; les suivants, la mutation). Défaut : { 0 }.
-- Renvoie l'objet sorti, la rareté de la caisse et la mutation lue sur son étiquette (toujours nil, vague 32),
-- et le nombre de valeurs forcées non lues.
function openAndReveal(p, store, n, luck, rolls)
	local box = boxAt(store, n)
	local startRarity, mutationText = boxLabel(box)
	openBox(p, store, n, luck)
	assert(isOpening(box), "ouverture refusée (rayon " .. n .. " de " .. store.Name .. ")")
	advance(SOS.revealDelay(luck) - 0.05)
	for _, v in rolls or { 0 } do
		table.insert(HEIST_FORCED, v)
	end
	advance(0.1)
	local left = #HEIST_FORCED
	table.clear(HEIST_FORCED)
	return itemAt(store, n), startRarity, mutationText, left
end
-- Envois Notify dont le texte contient `pattern`, depuis l'instant `since`.
function notifiesSince(pattern, since, to)
	local out = {}
	for _, e in notifies(pattern, to) do
		if e.t >= since then
			table.insert(out, e)
		end
	end
	return out
end

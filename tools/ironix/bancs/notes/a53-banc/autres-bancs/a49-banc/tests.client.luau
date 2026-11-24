--!nocheck
-- Scénario « client » (a49, DEV-131) : le vrai UnboxController et ses modules (Sequence, Screen) sur
-- l'écran UI_Unbox d'a46 (buildUnbox, repris de son scénario client). Le faux Roblox d'a46 n'a pas la
-- projection du rouleau (Reel s'arrête : « séquence d'ouverture interrompue », comme chez a46) : la
-- séquence complète n'est pas jouée ici. On vérifie : UnboxReveal reçu avec sa mutation (ligne [Unbox]
-- du client : nom « Big Gold Rubber Duck » et revenu × 4), Sequence.plan (revenu × mutation), et
-- Screen.ItemNameText (nom précédé de la mutation) sur une vue minimale.

advance(1000)
startServer()
local Format = sharedModule("Format")
local ada = join("Ada", newProfile(4))
advance(1.5)
local gui = buildUnbox(ada:FindFirstChild("PlayerGui"))
startClient(ada)
advance(0.5)

local base = Formulas.ItemIncome(2, "Common")
-- a51 (L-089) : colis rangé puis posé au sol (compat51) ; invite « Open » du client sur le FloorBox.
local function run(slot, mutation)
	local p = npcBox("Common", "Z2_CanardEnPlastique", "Standard", 2)
	p.Mutation = mutation
	placePayload(ada, slot, p)
	flush()
	advance(0.5)
	advance(math.max(0, slotBox(ada, slot).ReadyAt - serverTime()) + 0.5)
	goToStand(ada, slot)
	local prompt = floorBoxN(ada, slot):FindFirstChild("UnboxPrompt", true)
	prompt.Triggered:Fire()
	flush()
	advance(10)
end

section("UnboxReveal reçu par le client avec la mutation")
run(1, { Size = "Big", Effect = "Gold" })
check(logHas(`colis {slotUid(ada, 1)} : COMMON · Big Gold Rubber Duck · {base * 4} $/s`, "PRINT", "client"), `ligne [Unbox] du client : « Big Gold Rubber Duck · {base * 4} $/s »`)
check(logHas("mutation BIG · GOLD", "PRINT", "client"), "ligne [Unbox] du client : « mutation BIG · GOLD »")
run(2, nil)
check(logHas(`colis {slotUid(ada, 2)} : COMMON · Rubber Duck · {base} $/s`, "PRINT", "client"), "sans mutation : nom seul, revenu de base")

section("Sequence.plan et Screen.ItemNameText")
local unboxFolder = CONTROLLERS:FindFirstChild("Unbox")
local Sequence = requireModule(unboxFolder:FindFirstChild("Sequence"), "client")
local Screen = requireModule(unboxFolder:FindFirstChild("Screen"), "client")
local function plan(mutation)
	return Sequence.plan({ SlotIndex = 1, ItemUid = "x", ItemId = "Z2_CanardEnPlastique", Zone = 2, Tier = "Standard", StartRarity = "Common", Upgrades = 0, Mutation = mutation }, Random.new(1))
end
check(near(plan(nil).Income, base) and near(plan({ Size = "Colossal", Effect = "Rainbow" }).Income, base * 100) and near(plan({ Size = "Mega" }).Income, base), "Income du plan : ×1 sans mutation, ×100 Colossal Rainbow, ×1 si inconnue")
local label = gui:FindFirstChild("ItemName", true)
local view = { plan = plan({ Size = "Big", Effect = "Gold" }), itemName = label, saved = {} }
Screen.ItemNameText(view, 0)
check(label.Text == "Big Gold Rubber Duck" and label.Visible, `Screen.ItemNameText : « Big Gold Rubber Duck » ({label.Text})`)
view = { plan = plan(nil), itemName = label, saved = {} }
Screen.ItemNameText(view, 0)
check(label.Text == "Rubber Duck", `Screen.ItemNameText sans mutation : « Rubber Duck » ({label.Text})`)

summary("scénario client")

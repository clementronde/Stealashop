--!nocheck
-- Scénario « hand » du banc a206 (vague 63, règle de Clément L-192 Q3) : un objet retiré d'un présentoir à la main
-- (UnplaceItem, RemoveButton de UI_Displayed ; TakeDisplayItem, invite « Take ») va dans la main du joueur (vrai
-- HeldItemService.Give). Mains prises (autre objet tenu, outil, mort, portage) : dans la réserve.
advance(1000)
startServer()
local data = newProfile()
addItem(data, "s1", "Z1_Banane", 1, 1, 1)
addItem(data, "s2", "Z1_Banane", 2, 1, 2)
addItem(data, "s3", "Z1_Banane", 3, 1, 3)
addItem(data, "phone", "Z3_Smartphone", 4, 3, 4)
data.Items.phone.Mutation = { Size = "Big" }
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Held = serverModule("HeldItemService")
local function reserveOf(player)
	return table.concat(dataOf(player).Reserve or {}, ",")
end
local function shown(uid)
	for _, v in dataOf(ada).Display do
		if v == uid then
			return true
		end
	end
	return false
end
local function unplace(uid)
	fireAs(ada, "UnplaceItem", uid)
	flush()
	advance(0.2)
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(reserveOf(ada) == "" and dataOf(ada).Reserve ~= nil, "profil migré : réserve vide (tout est exposé)")

section("mains libres : l'objet retiré va dans la main")
local weight = dataOf(ada).Items.phone.Weight
unplace("phone")
local tool = heldTool(ada)
check(not shown("phone") and dataOf(ada).Items.phone ~= nil, "retiré du présentoir, gardé au joueur")
check(tool ~= nil and tool:GetAttribute("HeldItemUid") == "phone" and Held.GetHeld(ada) == "phone", "en main (Tool de l'objet)")
check(reserveOf(ada) == "", "pas dans la réserve")
check(#notifies(ada, "removed from its display") == 1, "Notify « removed from its display »")
check(dataOf(ada).Items.phone.Mutation.Size == "Big" and dataOf(ada).Items.phone.Weight == weight, "mutation et poids gardés")

section("un objet déjà en main : le suivant va dans la réserve")
unplace("s1")
check(not shown("s1") and Held.GetHeld(ada) == "phone", "le téléphone reste en main")
check(reserveOf(ada) == "s1", `s1 dans la réserve (« {reserveOf(ada)} »)`)
check(#notifies(ada, "moved to your reserve") == 1, "Notify « moved to your reserve »")
check(ada:GetAttribute("DisplayReserve") == "s1", "attribut DisplayReserve")

section("un outil en main : dans la réserve")
fireAs(ada, "PlaceItemAuto", "phone")
flush()
advance(0.2)
check(shown("phone") and #itemTools(ada) == 0, "téléphone reposé : mains vides")
local bat = make("Tool", { Name = "Bat" }, ada.Character)
unplace("s2")
check(not shown("s2") and Held.GetHeld(ada) == nil and reserveOf(ada) == "s1,s2", `outil en main : s2 dans la réserve (« {reserveOf(ada)} »)`)
bat:Destroy()

section("mort : dans la réserve")
local humanoid = ada.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
unplace("s3")
check(not shown("s3") and Held.GetHeld(ada) == nil and reserveOf(ada) == "s1,s2,s3", `mort : s3 dans la réserve (« {reserveOf(ada)} »)`)
humanoid.Health = 100

section("de la réserve vers un présentoir : l'objet en sort")
fireAs(ada, "PlaceFromReserve", "s2")
flush()
advance(1.2)
check(shown("s2") and reserveOf(ada) == "s1,s3", `s2 reposé (« {reserveOf(ada)} »)`)

section("un objet tenu ne se duplique pas")
unplace("phone")
check(Held.GetHeld(ada) == "phone" and #itemTools(ada) == 1, "un seul Tool")
fireAs(ada, "PlaceFromReserve", "phone")
flush()
advance(1.2)
check(not shown("phone") and Held.GetHeld(ada) == "phone", "en main, pas en réserve : PlaceFromReserve refusé")

summary("scénario hand")

--!nocheck
-- Scénario « pvp » (a49, DEV-131) : mise en place du banc a29 (copie d'a36), vrais PvPService,
-- DisplayService et CarryService. Un objet muté (Big Gold) se vole : son revenu exposé compte la
-- mutation (panneau, anti-racket, payload), la mutation voyage dans le payload, et l'objet déposé chez
-- le voleur la garde (même revenu, même taille). Un échec rend l'objet à la victime, mutation intacte.

startServer()
local Mutations = sharedModule("Config/Mutations")
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
adaData.Items["ada-soda"].Mutation = { Size = "Big", Effect = "Gold" } -- 1 × 4 = 4 $/s
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2) -- 1 $/s
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- 5 $/s : le meilleur, à l'abri
local ada = join("Ada", adaData)
local bobData = newProfile()
addItem(bobData, "bob-banana", "Z1_Banane", 1)
local bob = join("Bob", bobData)
advance(1.2)
local adaShop, bobShop = shopOf(ada), shopOf(bob)

section("revenu exposé de la victime")
check(ada:GetAttribute("Income") == 10, `revenu d'Ada : 4 + 1 + 5 = 10 $/s (trouvé {ada:GetAttribute("Income")})`)
check(adaShop:GetAttribute("SafeSlots") == "3", `à l'abri : le Pot de nouilles, 5 $/s (trouvé {adaShop:GetAttribute("SafeSlots")})`)
local adaSoda = DisplayService.GetExposed(ada)[1]
check(adaSoda ~= nil and adaSoda.Income == 4, "GetExposed : la Canette Big Gold rapporte 4 $/s")

section("vol de l'objet muté")
local broken = breakDoor(bob, adaShop)
check(broken, "porte d'Ada cassée")
check(steal(bob, adaShop, 1), "Bob porte la Canette")
local payload = CarryService.GetPayload(bob)
check(payload ~= nil and payload.Kind == "PlayerItem" and payload.Income == 4, `payload : revenu 4 $/s, mutation comprise ({payload and payload.Income})`)
check(payload ~= nil and payload.Mutation ~= nil and payload.Mutation.Size == "Big" and payload.Mutation.Effect == "Gold", "payload : Mutation = { Big, Gold }")
check(payload ~= nil and payload.Mutation ~= adaData.Items["ada-soda"].Mutation, "payload : une copie de la mutation, pas la table du profil")
-- Échec d'abord : l'objet revole chez Ada, mutation intacte ; puis second vol, réussi.
CarryService.Fail(bob, "Bat")
advance(1)
check(adaData.Items["ada-soda"].Mutation.Size == "Big" and adaData.Display["1"] == "ada-soda", "échec : la Canette revient chez Ada, mutation intacte")
check(ada:GetAttribute("Income") == 10, `échec : Ada retrouve ses 10 $/s ({ada:GetAttribute("Income")})`)
if not steal(bob, adaShop, 1) then
	breakDoor(bob, adaShop)
	steal(bob, adaShop, 1)
end
check(CarryService.IsCarrying(bob) and CarryService.GetPayload(bob).Mutation.Effect == "Gold", "second vol : payload Big Gold")
runHome(bob, adaShop)
check(not CarryService.IsCarrying(bob), "déposé chez Bob")
local entry = bobData.Items["ada-soda"]
check(entry ~= nil and entry.Source == "PvP" and entry.Mutation ~= nil and entry.Mutation.Size == "Big" and entry.Mutation.Effect == "Gold", "chez Bob : Items[uid].Mutation = { Big, Gold }, Source PvP")
check(adaData.Items["ada-soda"] == nil, "plus chez Ada")
local bobExposed
for _, e in DisplayService.GetExposed(bob) do
	if e.Uid == "ada-soda" then
		bobExposed = e
	end
end
check(bobExposed ~= nil and bobExposed.Income == 4, "exposé chez Bob : 4 $/s")
check(bob:GetAttribute("Income") == 5, `revenu de Bob : 1 + 4 = 5 $/s (trouvé {bob:GetAttribute("Income")})`)
local model
local folder = bobShop:FindFirstChild("DisplayItems")
for _, child in (folder and folder:GetChildren() or {}) do
	if child:GetAttribute("ItemUid") == "ada-soda" then
		model = child
	end
end
check(model ~= nil and model:GetAttribute("MutationSize") == "Big" and model:GetAttribute("MutationEffect") == "Gold", "modèle chez Bob : MutationSize Big, MutationEffect Gold")
local root = model and model.PrimaryPart
check(root ~= nil and math.abs(root.Size.Y - 1.6 * 1.5) < 1e-4, `modèle chez Bob : 1,5 fois plus grand ({root and root.Size.Y})`)
check(#notifies(bob, "+$4/s") >= 1, "message du voleur : revenu de l'objet (+$4/s)")

summary("scénario pvp")

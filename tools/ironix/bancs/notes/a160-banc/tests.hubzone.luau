-- Scénario hubzone (a160) : entrée et sortie des zones, bonus de 0 à 5 amis, textes des étiquettes.
local Hub, HubZone = realHub()
local zoneCF = CFrame.new(100, 0.5, 50)
local size = Vector3.new(10, 1, 10)

check(HubZone.contains(zoneCF, size, Vector3.new(100, 3.5, 50), 0), "Z1 centre, HRP à 3 studs au-dessus du disque : dedans")
check(not HubZone.contains(zoneCF, size, Vector3.new(106, 3.5, 50), 0), "Z2 à 1 stud du bord : dehors sans marge")
check(HubZone.contains(zoneCF, size, Vector3.new(106, 3.5, 50), Hub.ExitMargin), "Z3 même point : dedans avec la marge de sortie")
check(not HubZone.contains(zoneCF, size, Vector3.new(100, 30, 50), 0), "Z4 30 studs au-dessus : dehors")
check(not HubZone.contains(zoneCF, size, Vector3.new(100, -5, 50), 0), "Z5 sous le sol : dehors")

local inside, entered = HubZone.step(false, zoneCF, size, Vector3.new(120, 3, 50))
check(not inside and not entered, "S1 loin : dehors, pas d'entrée")
inside, entered = HubZone.step(inside, zoneCF, size, Vector3.new(104, 3, 50))
check(inside and entered, "S2 on entre : une entrée")
inside, entered = HubZone.step(inside, zoneCF, size, Vector3.new(100, 3, 50))
check(inside and not entered, "S3 on reste : pas de nouvelle entrée")
inside, entered = HubZone.step(inside, zoneCF, size, Vector3.new(106, 3, 50))
check(inside and not entered, "S4 sur le bord (dans la marge) : toujours dedans")
inside, entered = HubZone.step(inside, zoneCF, size, Vector3.new(108, 3, 50))
check(not inside and not entered, "S5 au-delà de la marge : dehors")
inside, entered = HubZone.step(inside, zoneCF, size, Vector3.new(102, 3, 50))
check(inside and entered, "S6 on revient : nouvelle entrée")
inside, entered = HubZone.step(inside, zoneCF, size, nil)
check(not inside and not entered, "S7 personnage mort ou absent : dehors")

local expected = { [0] = 0, 0.15, 0.30, 0.45, 0.60, 0.60 }
for n = 0, 5 do
	local got = HubZone.friendBonus(n)
	check(math.abs(got - expected[n]) < 1e-9, `F{n} {n} ami(s) : +{expected[n] * 100} % ({got})`)
end
check(HubZone.friendBonus(-1) == 0 and HubZone.friendBonus(0 / 0) == 0, "F6 nombre invalide : 0")
check(Hub.FriendBonus.PerFriend == 0.15 and Hub.FriendBonus.MaxFriends == 4, "F7 valeurs : +15 % par ami (Clément), 4 au plus (V0)")

check(HubZone.labelText("WeaponShop") == "WEAPONS", "L1 WeaponShop")
check(HubZone.labelText("FreeGift") == "FREE!", "L2 FreeGift")
check(HubZone.labelText("InviteFriend") == "INVITE A FRIEND: +15% MONEY PER FRIEND", `L3 InviteFriend ({HubZone.labelText("InviteFriend")})`)
for _, key in { "AuraShop", "RobuxShop", "PawnShop", "Wheel" } do
	check(type(HubZone.labelText(key)) == "string", `L4 {key} a un texte`)
end
check(HubZone.labelText("Nope") == nil and HubZone.labelText(42) == nil and HubZone.labelText(nil) == nil, "L5 clé inconnue ou pas un texte : nil")
check(not pcall(function() (Hub.Labels :: any).X = "y" end), "L6 Config/Hub gelée")

print(`{checks} vérification(s), {fails} échec(s)`)

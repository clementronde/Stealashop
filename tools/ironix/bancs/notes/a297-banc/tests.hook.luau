--!nocheck
-- Scénario « hook » (a297, serveur) : jeu DEV (caisse allumée), en Studio, sans zone safe (pas d'ouverture). Le crochet
-- MonetizationTest donne des reçus « STUDIO-<GUID du Play>-n » ; deux Play simulés (MonetizationService.BancNewPlay :
-- compteur à 0 et GUID oublié, comme au chargement du module) avec le même profil (Purchases gardés) donnent des reçus
-- différents, et le 1er essai du 2e Play est donné. Un même reçu rejoué : rien de plus (idempotence).
SET_ENVIRONMENT("Dev")
startServer()
local ada = join("Ada", newProfile())
advance(1.5)
local function exclusives()
	local n = 0
	for _, entry in dataOf(ada).Items do
		if string.find(entry.Id, "^Exclusive_") then
			n += 1
		end
	end
	return n
end
local function studioIds()
	local list = {}
	for id in dataOf(ada).Purchases do
		if string.find(id, "^STUDIO%-") then
			table.insert(list, id)
		end
	end
	return list
end
local function test(value)
	clearLog()
	local before = studioIds()
	Workspace:SetAttribute("MonetizationTest", value)
	advance(0.5)
	local new = {}
	for _, id in studioIds() do
		if not table.find(before, id) then
			table.insert(new, id)
		end
	end
	return new
end

section("H1 1er Play : deux essais, deux reçus")
local n0 = exclusives()
local a = test("Ada Crate1")
local b = test("Ada Crate1")
check(#a == 1 and #b == 1 and a[1] ~= b[1], `deux reçus différents ({a[1]}, {b[1]})`)
check(a[1] ~= nil and string.match(a[1], "^STUDIO%-.+%-1$") ~= nil and a[1] ~= "STUDIO-1", `forme STUDIO-<GUID>-1 ({a[1]})`)
local sessionA = a[1] and string.match(a[1], "^STUDIO%-(.+)%-1$")
check(b[1] ~= nil and b[1] == `STUDIO-{sessionA}-2`, `même GUID dans le même Play, compteur 2 ({b[1]})`)
check(exclusives() == n0 + 2, "2 objets donnés")

section("H2 2e Play, même profil : le 1er essai est donné")
check(MonetizationService.BancNewPlay ~= nil, "BancNewPlay exposé au banc")
MonetizationService.BancNewPlay()
local kept = #studioIds()
check(kept == 2, `le profil garde ses 2 reçus du 1er Play ({kept})`)
local c = test("Ada Crate1")
check(#c == 1 and c[1] ~= a[1] and c[1] ~= b[1], `reçu neuf ({c[1]})`)
local sessionC = c[1] and string.match(c[1], "^STUDIO%-(.+)%-1$")
check(sessionC ~= nil and sessionC ~= sessionA, `un autre GUID, compteur reparti de 1 ({sessionC})`)
check(exclusives() == n0 + 3, "1er essai du 2e Play : objet donné")
check(not logHas("déjà donné"), "pas de « déjà donné »")
check(c[1] ~= nil and logHas(`test : Crate1 pour Ada (reçu {c[1]}) → PurchaseGranted`, "PRINT", "server"), "réponse écrite dans la sortie")

section("H3 un même reçu rejoué : rien de plus")
clearLog()
check(settle(receipt(ada, 8401, c[1])) == GRANTED, "reçu du crochet rejoué : PurchaseGranted")
check(exclusives() == n0 + 3, "aucun objet de plus")
check(logHas(`reçu {c[1]} (Crate) déjà donné, rien de plus`), "la sortie dit : déjà donné")
summary("scénario hook")

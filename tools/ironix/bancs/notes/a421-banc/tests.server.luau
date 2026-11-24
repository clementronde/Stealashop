--!nocheck
-- a421 (L-316) : StoreHeistService pendant la cinématique d'ouverture (Features.SingleBoxReveal) : colis marqué RevealId
-- (id de la cinématique) de RevealStarted à RevealEnded ; un 2e appui (ouvreur ou autre joueur) refusé par le serveur ;
-- marque retirée à la fin (RevealDone, mort). Mise en place du banc a202 ; OpenShelfBox par étapes écrites.
startAll(true)
local Rar = sharedModule("Config/Rarities")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
flush()
local LMIN = luckValues()[1]

-- Maintien complet : "Begin", temps de prise de la rareté du colis (+ 0,05 s), "End" ; chance `luck` forcée au lancement.
local lastAt = {}
local function press(p, box, luck)
	local slotId = box:GetAttribute("SlotId")
	local last = lastAt[p]
	if last and now() - last < 0.3 then
		advance(0.3)
	end
	table.clear(HEIST_FORCED)
	fireAs(p, "OpenShelfBox", slotId, "Begin")
	advance(Rar.GrabTime(box:GetAttribute("BoxRarity")) + 0.05)
	if luck then
		table.insert(HEIST_FORCED, luckRoll(luck))
	end
	lastAt[p] = now()
	fireAs(p, "OpenShelfBox", slotId, "End")
	flush()
	table.clear(HEIST_FORCED)
end

section("S1 ouverture : colis marqué RevealId, sans aucun ShelfOpen*")
reopen(A, STORE_A)
standAt(A, STORE_A, 1)
local box1 = boxAt(STORE_A, 1)
local started = #revealsOf(A)
press(A, box1, LMIN)
local ev = lastReveal(A)
local id1 = if ev then ev.args[10] else nil
check(#revealsOf(A) == started + 1 and type(id1) == "string", "S1 (banc) cinématique lancée (" .. tostring(id1) .. ")")
check(box1:GetAttribute("RevealId") == id1, "S1 colis marqué RevealId = id de la cinématique (reçu " .. tostring(box1:GetAttribute("RevealId")) .. ")")
check(noShelfAttrs(box1), "S1 toujours aucun attribut ShelfOpen* (l'ouverture d'avant ne joue pas chez le client)")
check(boxAt(STORE_A, 2) ~= nil and boxAt(STORE_A, 2):GetAttribute("RevealId") == nil, "S1 colis voisin pas marqué")

section("S2 réappui pendant la cinématique : refusé par le serveur")
clearLog()
press(A, box1, LMIN)
check(#revealsOf(A) == started + 1, "S2 ouvreur : aucune 2e cinématique sur le même colis")
check(logHas("OpenShelfBox de Alice", "WARN"), "S2 (Studio) refus écrit pour Alice")
check(protected(A) and box1:GetAttribute("RevealId") == id1 and not isDestroyed(box1), "S2 cinématique d'origine intacte")
fireAs(A, "OpenShelfBox", box1:GetAttribute("SlotId"), "End")
flush()
check(#revealsOf(A) == started + 1, "S2b « End » seul envoyé par un client : rien")
advance(1.1) -- avance du casseur passée pour Bob
standAt(B, STORE_A, 1, 4)
clearLog()
press(B, box1, LMIN)
check(#revealsOf(B) == 0, "S2c autre joueur : aucune cinématique sur le colis en cours d'ouverture")
check(logHas("ouverture déjà lancée", "WARN"), "S2c (Studio) refus « ouverture déjà lancée » pour Bob")
standAt(A, STORE_A, 2)
press(A, boxAt(STORE_A, 2), LMIN)
check(#revealsOf(A) == started + 1, "S2d ouvreur : aucun autre colis pendant sa cinématique (un seul colis par braquage)")

section("S3 fin par RevealDone : marque retirée, colis retiré, objet porté")
revealDone(A, id1)
check(#endedFor(id1) == 1, "S3 (banc) RevealEnded envoyé")
check(box1:GetAttribute("RevealId") == nil, "S3 marque RevealId retirée")
check(isDestroyed(box1) and boxAt(STORE_A, 1) == nil, "S3 colis retiré du rayon")
check(Carry.IsCarrying(A), "S3 (banc) Alice porte son objet")

section("S4 mort pendant la cinématique : marque retirée, objet posé sans marque")
standAt(B, STORE_A, 3)
local box3 = boxAt(STORE_A, 3)
press(B, box3, LMIN)
local evB = lastReveal(B)
local idB = if evB then evB.args[10] else nil
check(type(idB) == "string" and box3:GetAttribute("RevealId") == idB, "S4 Bob ouvre : colis marqué (" .. tostring(idB) .. ")")
humanoidOf(B).Health = 0
advance(0.3)
check(#endedFor(idB) == 1 and not protected(B), "S4 (banc) RevealEnded, protection levée")
check(box3:GetAttribute("RevealId") == nil, "S4 marque retirée")
local left = itemAt(STORE_A, 3)
check(left ~= nil and left:GetAttribute("RevealId") == nil, "S4 objet posé sur le rayon, sans marque (invite « Steal » normale)")

summary("scénario server")

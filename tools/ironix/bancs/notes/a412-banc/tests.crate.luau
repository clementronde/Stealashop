--!nocheck
-- Scénario « crate » (a412, serveur, vague GC7 : textes du jeu, point 1) : jeu DEV, ouverture coupée
-- (Crate.Reveal.Enabled = false : tous les messages tout de suite), tirage remplacé pour donner les 6 objets de la caisse
-- dans l'ordre de Crate.Items. Chaque message « Exclusive Crate: you got … » porte le bon article (a / an) et la rareté en
-- DisplayName (plus de « a EPIC »).
SET_ENVIRONMENT("Dev")
REPLACE("shared/Config/Monetization.luau", "Enabled = true, -- V0 de Cantin, 21/11 ; false", "Enabled = false, -- V0 de Cantin, 21/11 ; false")
REPLACE(
	"server/Services/MonetizationService.luau",
	"local function drawCrate(): string\n",
	"local bancDraws = 0 -- banc a412 : tirages dans l'ordre de Crate.Items\nlocal function drawCrate(): string\n\tbancDraws += 1\n\tif bancDraws > 0 then\n\t\treturn CRATE.Items[(bancDraws - 1) % #CRATE.Items + 1]\n\tend\n"
)
local zone = make("Part", { Name = "SafeZone_Banc", Anchored = true, CanCollide = false, Size = Vector3.new(800, 200, 800), CFrame = CFrame.new(0, 50, 0) }, MAP)
CollectionService:AddTag(zone, "SafeZone")
startServer()
local PREFIX = "Exclusive Crate: you got "
local ada = join("Ada", newProfile())
advance(1.5)

section("C1 les 6 objets de la caisse : article et rareté justes")
local EXPECTED = {
	"Exclusive Crate: you got an Epic Disco Ball!",
	"Exclusive Crate: you got an Epic Golden Gramophone!",
	"Exclusive Crate: you got a Legendary Golden Rocket!",
	"Exclusive Crate: you got a Mythic Crystal Skull!",
	"Exclusive Crate: you got a Secret Neon Jukebox!",
	"Exclusive Crate: you got a Divine Golden Planet!",
}
check(#Monetization.Crate.Items == #EXPECTED, `6 objets dans la caisse ({#Monetization.Crate.Items})`)
local m0 = #notifies(ada, PREFIX)
check(settle(receipt(ada, 8402, "A412-3")) == GRANTED, "x3 : PurchaseGranted")
check(settle(receipt(ada, 8402, "A412-3b")) == GRANTED, "x3 encore : PurchaseGranted")
advance(0.3)
flush()
local all = notifies(ada, PREFIX)
check(#all == m0 + 6, `6 messages ({#all - m0})`)
for index, text in EXPECTED do
	local got = notifies(ada, text)
	check(#got == 1, `objet {index} : « {text} » ({#got})`)
end

section("C2 plus de rareté en capitales ni de « a » devant une voyelle")
local bad = 0
for _, e in all do
	local text = e.args[1]
	if string.find(text, "you got a [AEIOU]") or string.find(text, "%u%u%u") then
		bad += 1
		print("  message fautif : " .. text)
	end
end
check(bad == 0, `aucun message fautif ({bad})`)
summary("scénario crate")

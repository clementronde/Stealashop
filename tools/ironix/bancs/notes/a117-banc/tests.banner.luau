--!nocheck
-- Scénario « banner » d'a117 (vague 34, 2026-11-13, L-127 point 1), sur le faux Roblox de la copie a101 du banc a42 :
-- UI_ZoneBanner écrit seulement le chiffre dans Advice.Speed et Advice.Damage (Format.short : « 28 », « 40K ») ;
-- SpeedIcon et DamageIcon disent déjà ce que c'est. Les couleurs et Difficulty ne changent pas.
local Zones = sharedModule("Config/Zones", "client")
local Format = sharedModule("Format", "client")

buildZoneBannerUi()
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
local gui = copyScreen(alice, StarterGui.UI_ZoneBanner)
startClient(alice)
local Banner = clientModule("ZoneBannerController")

section("L-132. le mot et le chiffre, zone par zone")
for zone = 1, #Zones do
	Banner.Show(zone)
	advance(0.1)
	local speed, damage = gui.Banner.Advice.Speed.Text, gui.Banner.Advice.Damage.Text
	check(
		speed == "Speed " .. Format.short(Zones[zone].AdvisedSpeed) and damage == "Damage " .. Format.short(Zones[zone].AdvisedDamage),
		`zone {zone} : « {speed} », « {damage} » (« Speed N », « Damage N », Format.short)`
	)
	check(not string.find(damage, "Strength"), `zone {zone} : pas « Strength »`)
end
check(gui.Banner.Advice.Speed.Text == "Speed 48" and gui.Banner.Advice.Damage.Text == "Damage 40K", "zone 6 : « Speed 48 », « Damage 40K »")
check(gui.Banner.Difficulty.Text == "Hard", "Difficulty inchangé (« Hard » avec 0 de force)")

summary("scénario banner")

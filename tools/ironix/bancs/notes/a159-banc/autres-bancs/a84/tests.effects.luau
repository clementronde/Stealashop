--!nocheck
-- Copie a159 (2026-11-14, L-163) : porte en coups (40, +8 par niveau de Reinforced Door), réparation en part du maximum, casse en coups.
-- Scénario « effects » (a84) : effets codés sur la boutique du joueur, par les vrais WindowService et
-- PvPService. Glass : PV max × Effects[niveau], à fraction de PV égale ; Glass Regen : réparation de
-- Effects[niveau] des PV max par seconde (base 3 %) ; Safe : présentoirs à l'abri = 1 + Effects[niveau].
startSkills()
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- Rare : le meilleur
addItem(adaData, "ada-donut", "Z1_Donut", 4)
adaData.Cash = 1e12
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
advance(1.2)
local adaShop = shopOf(ada)
local door = doorOf(adaShop)

section("Glass (GlassThickness)")
check(door:GetAttribute("MaxHP") == 40, `copie a159 : base 40 coups (trouvé {door:GetAttribute("MaxHP")})`)
buy(ada, "GlassThickness")
check(door:GetAttribute("MaxHP") == 48, `niveau 1 : 48 coups (trouvé {door:GetAttribute("MaxHP")})`)
buy(ada, "GlassThickness")
check(door:GetAttribute("MaxHP") == 56, `niveau 2 : 56 coups (trouvé {door:GetAttribute("MaxHP")})`)
hitDoor(bob, adaShop, 20)
local hp, max = lastHP(adaShop)
check(max == 56 and hp < 56, `coups de Bob : {hp} / {max}`)
local fraction = hp / max
buy(ada, "GlassThickness")
local hp3, max3 = lastHP(adaShop)
check(max3 == 64 and math.abs(hp3 / max3 - fraction) < 0.04, `niveau 3 : 64 coups, même fraction de PV ({string.format("%.3f", fraction)} → {string.format("%.3f", hp3 / max3)})`)

section("Glass Regen (GlassRegen)")
local function regenRate()
	hitDoor(bob, adaShop, 15) -- copie a159 : 15 coups tentés (5 par seconde comptés)
	advance(3.1) -- copie a159 : la porte ne se répare qu'après 3 s sans coup (L-163)
	local h0 = lastHP(adaShop)
	advance(1)
	local h1, m = lastHP(adaShop)
	return (h1 - h0) / m
end
local base = regenRate()
check(math.abs(base - 0.03) < 0.004, `base : 3 %/s (mesuré {string.format("%.4f", base)})`)
buy(ada, "GlassRegen")
local r1 = regenRate()
check(math.abs(r1 - 0.04) < 0.004, `niveau 1 : 4 %/s (mesuré {string.format("%.4f", r1)})`)
Workspace:SetAttribute("SkillTest", "Ada GlassRegen 5")
advance(0.1)
local r5 = regenRate()
check(math.abs(r5 - 0.08) < 0.006, `niveau 5 : 8 %/s (mesuré {string.format("%.4f", r5)})`)
check(door:GetAttribute("MaxHP") == 64, "la réparation ne change pas le maximum de coups")

section("Safe")
local function safeCount()
	local text = adaShop:GetAttribute("SafeSlots")
	return if text then #string.split(text, ",") else 0, text
end
local n0, t0 = safeCount()
check(n0 == 1 and t0 == "3", `base : 1 présentoir à l'abri, le 3 (trouvé {t0})`)
buy(ada, "Safe")
advance(0.6)
local n1, t1 = safeCount()
check(n1 == 2, `niveau 1 : 2 à l'abri (trouvé {t1})`)
buy(ada, "Safe")
advance(0.6)
local n2, t2 = safeCount()
check(n2 == 3 and t2 == "1,2,3", `niveau 2 : 3 à l'abri, 1,2,3 (trouvé {t2})`)
check(PvPService.GetVaultSlots(ada) == 3 and PvPService.GetVaultSlots(bob) == 1, "PvPService.GetVaultSlots : 3 chez Ada, 1 chez Bob")
advance(5)
WindowService.GetPlotRegen = function()
	return 0
end
check(breakDoor(bob, adaShop, 120), "Bob casse la porte d'Ada (64 coups, réparation coupée dans le banc)")
check(not steal(bob, adaShop, 1), "présentoir 1 à l'abri : prise refusée")
check(#notifies(bob, "This item is in the safe") >= 1, "message du coffre-fort au voleur")
check(steal(bob, adaShop, 4), "présentoir 4 (pas à l'abri) : prise acceptée")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("valeur de base gardée", "WARN"), "aucun point d'accroche en erreur")
summary("scénario effects")

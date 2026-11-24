---------------------------------------------------------------- scénario « bubble » : « +X Speed » pour une bulle, « +X Speed/s » pour le tapis
local hud, Gain = startBanc(10, nil)
local BG = HudCfgC.BubbleGain
check(BG ~= nil and BG.Text == "+%s Speed" and type(BG.Window) == "number", "B0 Config/Hud.BubbleGain : « +%s Speed », Window")
P1:SetAttribute("TrainingMachine", "Treadmill")
local function texts()
	local out = {}
	for _, f in flyers(hud) do
		table.insert(out, el(f, "Amount").Text)
	end
	table.sort(out)
	return table.concat(out, " | ")
end

print("\n== B1. Seconde du tapis : « +8 Speed/s » inchangé")
credit(18)
check(texts() == "+8 Speed/s", `B1a ({texts()})`)
step(1.3)
check(speedText(hud) == "18", `B1b compteur 18 ({speedText(hud)})`)

print("\n== B2. Bulle ×4 prise : BubbleGone(gain 32) puis la hausse de Speed")
Gain.NoteBubble(32)
credit(50)
check(texts() == "+32 Speed", `B2a « +32 Speed », sans « /s » ({texts()})`)
check(speedText(hud) == "18", `B2b compteur retenu pendant le vol ({speedText(hud)})`)
step(1.3)
check(speedText(hud) == "50" and #flyers(hud) == 0, `B2c arrivé : 50 ({speedText(hud)})`)

print("\n== B3. Bulle ×2 (16) et seconde du tapis (+12) dans la même hausse (+28) : deux textes, même total")
Gain.NoteBubble(16)
credit(78)
check(texts() == "+12 Speed/s | +16 Speed", `B3a deux textes séparés ({texts()})`)
check(speedText(hud) == "50", `B3b compteur retenu ({speedText(hud)})`)
step(1.3)
check(speedText(hud) == "78" and #flyers(hud) == 0, `B3c total juste : 78 ({speedText(hud)})`)

print("\n== B4. Annonce trop vieille (jamais vue monter) : oubliée")
Gain.NoteBubble(16)
step(BG.Window + 0.1)
credit(86)
check(texts() == "+8 Speed/s", `B4 seconde du tapis normale ({texts()})`)
step(1.3)

print("\n== B5. Annonces invalides ignorées")
Gain.NoteBubble(0 / 0)
Gain.NoteBubble(-5)
Gain.NoteBubble(math.huge)
credit(94)
check(texts() == "+8 Speed/s", `B5 ({texts()})`)
step(1.3)

print("\n== B6. Deux bulles avant la hausse (deux prises dans la même image) : un texte de bulle, total")
Gain.NoteBubble(16)
Gain.NoteBubble(24)
credit(134)
check(texts() == "+40 Speed", `B6 ({texts()})`)
step(1.3)
check(speedText(hud) == "134", `B6b compteur 134 ({speedText(hud)})`)

print("\n== B7. VISUAL EFFECTS sur OFF : « +32 Speed » sur place, compteur tout de suite")
P1:SetAttribute("VfxEnabled", false)
Gain.NoteBubble(32)
credit(166)
local bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
check(#flyers(hud) == 0 and #bbs == 1 and el(bbs[1], "Amount").Text == "+32 Speed", `B7a ({bbs[1] and el(bbs[1], "Amount").Text})`)
check(speedText(hud) == "166", `B7b compteur tout de suite ({speedText(hud)})`)
step(1.3)
credit(174)
bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
check(#bbs == 1 and el(bbs[1], "Amount").Text == "+8 Speed/s", `B7c tapis sur place inchangé ({bbs[1] and el(bbs[1], "Amount").Text})`)
step(1.3)
P1:SetAttribute("VfxEnabled", true)

print("\n== B8. Trail ×3 : le gain de bulle garde l'exposant du trail")
P1:SetAttribute("TrailMultiplier", 3)
credit(174)
step(0.1)
Gain.NoteBubble(32)
credit(206)
local f = flyers(hud)[1]
local amount = f and el(f, "Amount")
check(amount ~= nil and string.match(amount.Text, "^%+32 +Speed$") ~= nil, `B8a ({amount and amount.Text})`)
if amount then
	checkLine("B8", amount, "+32", "×3")
end
step(1.3)
check(speedText(hud) == FormatC.short(FormulasC.ShownSpeed(206, 3)), `B8c compteur juste ({speedText(hud)})`)
summary()

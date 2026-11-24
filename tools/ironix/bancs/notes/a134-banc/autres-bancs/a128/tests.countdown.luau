---------------------------------------------------------------- a128 (vague 39, 2026-11-14)
-- Scénario « countdown » : collé après les scénarios du banc a21-hud (sans leur bilan), même place et même
-- HudController. Correction 4 de perf-telephone.md : le texte de NightCountdown n'est recalculé (attributs
-- de phase relus, texte formaté) que quand la seconde affichée change ou qu'un attribut de phase change.
-- Compté : les lectures de l'attribut NightPhase du Workspace (une par calcul).
print("\n== a128. NightCountdown recalculé seulement quand la seconde change")
local countdownReads = 0
local realGetAttribute = Workspace.GetAttribute
rawset(Workspace, "GetAttribute", function(self, name)
	if name == "NightPhase" then
		countdownReads += 1
	end
	return realGetAttribute(self, name)
end)
setPhase("Day", 450, 480.5)
step(0.1)
check(T("NightCountdown") == "Night in 8:01", `a128 jour : « Night in 8:01 » ({T("NightCountdown")})`)
step(0.3) -- même seconde affichée (8:01 jusqu'à 0,5 s)
countdownReads = 0
step(0.05)
check(countdownReads == 0, `a128 même seconde : aucun calcul ({countdownReads})`)
step(0.1) -- passe 0,5 s : 8:00
check(T("NightCountdown") == "Night in 8:00" and countdownReads == 1, `a128 la seconde change : un calcul, « Night in 8:00 » ({countdownReads}, {T("NightCountdown")})`)
countdownReads = 0
step(10)
check(T("NightCountdown") == "Night in 7:50", `a128 10 s plus tard : « Night in 7:50 » ({T("NightCountdown")})`)
check(countdownReads >= 10 and countdownReads <= 11, `a128 10 s à 30 images/s : 10 calculs au lieu de 300 ({countdownReads})`)
countdownReads = 0
setPhase("Night", 120)
step(1 / 30)
check(T("NightCountdown") == "Dawn in 2:00" and countdownReads >= 1, `a128 attribut de phase changé : recalculé à l'image suivante ({T("NightCountdown")})`)
setPhase("Warning", 2.2)
step(1 / 30)
check(T("NightCountdown") == "NIGHT FALLS IN 3s", `a128 alerte : « NIGHT FALLS IN 3s » ({T("NightCountdown")})`)
step(2.3)
check(T("NightCountdown") == "NIGHT FALLS IN 0s", `a128 alerte finie : « 0s » ({T("NightCountdown")})`)
countdownReads = 0
step(3)
check(countdownReads == 0 and T("NightCountdown") == "NIGHT FALLS IN 0s", `a128 à 0 s : plus aucun calcul avant le prochain attribut ({countdownReads})`)
hud:Destroy()
hud = makeHud(playerGui, true)
step(1 / 30)
check(T("NightCountdown") == "NIGHT FALLS IN 0s", `a128 nouvel écran : texte écrit tout de suite ({T("NightCountdown")})`)
rawset(Workspace, "GetAttribute", nil)

summary()
print(string.format("scénario countdown : %d vérification(s), %d échec(s)", CHECKS, FAILS))

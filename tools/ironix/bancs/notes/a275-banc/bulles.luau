-- a275 (vague GC2, 23/11, audit a272 F3) : ajouté à la fin du fichier assemblé du banc a214 (mêmes aides, même monde ;
-- Bob, car Alice a quitté le serveur au scénario L8). La séance est simulée (TrainingService.IsTraining vrai pour Bob) :
-- la montée sur le tapis du banc a214 dépend de règles du tapis qui changent d'une vague à l'autre.
print("--- a275")
CHECKS, FAILS = 0, 0
do
	check("B0 Config/Bubbles.ClaimMinAge = 0,4 (V0)", Bubbles.ClaimMinAge == 0.4, Bubbles.ClaimMinAge)
	local baseIsTraining = TrainingService.IsTraining
	TrainingService.IsTraining = function(p)
		return p == bob or baseIsTraining(p)
	end
	check("B1 Bob en séance (simulée)", TrainingService.IsTraining(bob))
	local since = NOW
	local s = nil
	for _ = 1, 400 do -- image par image jusqu'à la première bulle
		step(FRAME, FRAME)
		s = spawnsOf(bob, since)[1]
		if s then
			break
		end
	end
	check("B2 une bulle", s ~= nil)
	if s then
		local ok, why = BubbleService.Claim(bob, s.id)
		check("B3 prise à son apparition : refusée « TooSoon »", ok == false and why == "TooSoon", why)
		check("B4 elle reste à prendre, aucun BubbleGone", alive(bob) >= 1 and goneOf(bob, s.id) == nil)
		step(0.3, FRAME)
		local ok2, why2 = BubbleService.Claim(bob, s.id)
		check("B5 à 0,3 s : encore « TooSoon »", ok2 == false and why2 == "TooSoon", why2)
		step(0.15, FRAME)
		local ok3, gain = BubbleService.Claim(bob, s.id)
		check("B6 à 0,45 s : acceptée", ok3 == true, gain)
		local g = goneOf(bob, s.id)
		check("B7 BubbleGone « Claimed »", g ~= nil and g.reason == "Claimed")
	end
	-- Une bulle trop jeune ne cache pas les autres refus : un id inconnu reste « Unknown ».
	step(0.15, FRAME)
	local okU, whyU = BubbleService.Claim(bob, "B999999")
	check("B8 id inconnu : « Unknown »", okU == false and whyU == "Unknown", whyU)
	TrainingService.IsTraining = baseIsTraining
	step(0.1, FRAME)
end
print(`banc a275-bulles : {CHECKS} vérification(s), {FAILS} échec(s)`)

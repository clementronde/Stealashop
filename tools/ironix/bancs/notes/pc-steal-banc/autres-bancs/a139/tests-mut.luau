-- a139 : lu après les scénarios du banc a119, dans la même fonction (leurs locales servent ici).
-- A139_PERF = "on" (Config/PerfClient tel quel) ou "off" (réglages coupés : l'ancien comportement).
print("== a139 : MutationFxController, effets hors de l'écran et objets sans mutation")
local ON = A139_PERF == "on"
local cam = Workspace.CurrentCamera
local FRONT = CFrame.new(0, 10, 20)
local BACK = CFrame.new(0, 10, 20) * CFrame.Angles(0, math.pi, 0) -- regarde vers +Z : les objets en z < 20 derrière
cam.CFrame = FRONT
local rb, rbBody = makeItem("ITM_A139Rainbow", "DisplayItem", "Rainbow", nil, Vector3.new(0, 0, -20))
local carriedRb, carriedRbBody = makeItem("CarryA139Rainbow", "CarriedItem", "Rainbow", nil, Vector3.new(4, 0, -20), { anchored = false })
local gl, glBody = makeItem("ITM_A139Glitch", "DisplayItem", "Glitch", nil, Vector3.new(-4, 0, -20))
local glOrig = glBody.CFrame
advance(0.6)
check(Fx.GetState(rb) ~= nil and Fx.GetState(rb).Shown and Fx.GetState(gl) ~= nil, "a139 : Rainbow et Glitch habillés et montrés")
local c0 = rbBody.Color
advance(0.2)
check(rbBody.Color ~= c0, "à l'écran : Rainbow animé")

cam.CFrame = BACK
advance(0.3)
local c1, cc1 = rbBody.Color, carriedRbBody.Color
advance(0.5)
if ON then
	check(rbBody.Color == c1, "hors de l'écran : objet exposé plus animé (couleur figée)")
	check((glBody.CFrame.Position - glOrig.Position).Magnitude < 1e-9, "hors de l'écran : Glitch, pièces à leur place exacte (saut fini)")
	local st = Fx.GetState(gl)
	check(st ~= nil and st.Bursting == false and st.Jumping == false, "hors de l'écran : pas de saut en cours")
else
	check(rbBody.Color ~= c1, "PerfClient coupé : animé hors de l'écran, comme avant")
end
check(carriedRbBody.Color ~= cc1, "objet porté hors de l'écran : toujours animé")
check(Fx.GetState(rb).Shown == true and holderOf(rb).Parent ~= nil, "hors de l'écran : effets gardés (particules, doubles)")

cam.CFrame = FRONT
advance(0.3)
local c2 = rbBody.Color
advance(0.2)
check(rbBody.Color ~= c2, "revenu à l'écran : de nouveau animé")
-- Bord de l'écran : la sphère (boîte, doubles, lumière) agrandie de la marge garde l'objet animé.
-- Champ de 70° sur 1280 × 720 : à 40 studs devant, le bord est à 49,8 studs du centre ; l'objet à 54,8 studs a
-- son centre hors du champ, mais sa lumière (portée 9) y entre.
cam.CFrame = FRONT * CFrame.new(-54.8, 0, 0)
advance(0.3)
local c3 = rbBody.Color
advance(0.2)
check(rbBody.Color ~= c3, "au bord de l'écran : animé")
cam.CFrame = FRONT
advance(0.3)

-- Objet sans mutation : relu seulement quand ses attributs changent.
local plain, plainBody = makeItem("ITM_A139Plain", "DisplayItem", nil, nil, Vector3.new(8, 0, -20))
advance(0.6)
local baseGet = Methods.GetAttribute
local reads = 0
Methods.GetAttribute = function(self, k)
	if self == plain and (k == "MutationEffect" or k == "MutationSize") then
		reads += 1
	end
	return baseGet(self, k)
end
advance(1)
Methods.GetAttribute = baseGet
-- MutationFxCacheFlags coupé dans Config/PerfClient le 2026-11-14 (aucun gain mesuré en Play) : en « on », ce
-- contrôle suit la valeur réelle du fichier, pas seulement A139_PERF.
local CACHE_ON = ON and string.find(SOURCES["shared/Config/PerfClient.luau"] or "", "MutationFxCacheFlags%s*=%s*true") ~= nil
if CACHE_ON then
	check(reads == 0, `objet sans mutation : plus relu à chaque contrôle ({reads} lectures en 1 s)`)
else
	check(reads >= 4, `PerfClient coupé : relu à chaque contrôle, comme avant ({reads})`)
end
plain:SetAttribute("MutationEffect", "Gold")
advance(0.6)
check(Fx.GetState(plain) ~= nil and plainBody.Color ~= BODY, "mutation ajoutée ensuite : habillé")
plain:SetAttribute("MutationEffect", nil)
advance(0.6)
check(Fx.GetState(plain) == nil and plainBody.Color == BODY, "mutation retirée : remis comme avant")
plain:SetAttribute("MutationSize", "Big")
advance(0.6)
plain:SetAttribute("MutationEffect", "Shiny")
advance(0.6)
check(Fx.GetState(plain) ~= nil, "taille puis effet : habillé")

local others = 0
for _, l in LOG do
	if l.kind == "ERROR" or (l.kind == "WARN" and not string.find(l.text, "FX_Mutation_Diamond absent", 1, true)) then
		others += 1
	end
end
check(others == 0, "a139 : aucune erreur ni autre avertissement")

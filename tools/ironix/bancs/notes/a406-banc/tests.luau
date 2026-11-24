-- Scénarios du banc a406 (L-297) : calculs de ShopBuildPlan, valeurs de repli de Config/ShopBuild, fiche du contrat.
CHECKS, FAILS = 0, 0
local function check(ok, label)
	CHECKS += 1
	if not ok then
		FAILS += 1
		print("ÉCHEC : " .. label)
	elseif VERBOSE then
		print("ok : " .. label)
	end
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local Plan = shared("ShopBuildPlan")
local ShopBuild = shared("Config/ShopBuild")
local Models = shared("Contract/Models")

-- Courbe Back
check(Plan.backOut(0, 1.9) == 0 and Plan.backOut(1, 1.9) == 1, "B1 backOut : 0 → 0, 1 → 1")
check(Plan.backOut(-1, 1.9) == 0 and Plan.backOut(2, 1.9) == 1, "B2 backOut borné hors de [0, 1]")
local peak = 0
for i = 1, 99 do
	peak = math.max(peak, Plan.backOut(i / 100, 1.9))
end
check(peak > 1.05 and peak < 1.3, "B3 backOut 1,9 dépasse (rebond) : pic " .. peak)
check(Plan.backOut(0.5, 0) <= 1, "B4 backOut sans dépassement : jamais plus de 1")
local up = true
for i = 1, 30 do
	if Plan.backOut(i / 100, 1.9) <= Plan.backOut((i - 1) / 100, 1.9) then
		up = false
	end
end
check(up, "B5 backOut monte au départ")

-- Ordre et plafond
local items = {
	{ bottom = 2, volume = 1 },
	{ bottom = 0, volume = 5 },
	{ bottom = 1, volume = 3 },
	{ bottom = 0, volume = 2 },
}
local order, rest, step = Plan.plan(items, 10, 0.09, 0.2, 2.5)
check(#order == 4 and #rest == 0, "P1 sous le plafond : toutes les pièces tombent")
check(order[1] == 2 and order[2] == 4 and order[3] == 3 and order[4] == 1, "P2 du bas vers le haut, égalité : rang d'origine (" .. table.concat(order, ",") .. ")")
check(near(step, 0.09), "P3 écart gardé (0,09) quand la durée tient")
order, rest, step = Plan.plan(items, 2, 0.05, 0.2, 2.5)
check(#order == 2 and #rest == 2, "P4 plafond 2 : 2 tombent, 2 d'un coup")
table.sort(order)
check(order[1] == 2 and order[2] == 3, "P5 les plus grosses tombent (volumes 5 et 3)")
check(rest[1] == 1 and rest[2] == 4, "P6 le reste trié par rang")
local many = {}
for i = 1, 200 do
	many[i] = { bottom = i % 7, volume = i }
end
order, rest, step = Plan.plan(many, 60, 0.05, 0.2, 2.5)
check(#order == 60 and #rest == 140, "P7 étage de 200 pièces : 60 tombent (V0 L-297 Q1)")
check(near((#order - 1) * step + 0.2, 2.5), "P8 écart réduit : dernière pièce posée en 2,5 s (" .. step .. ")")
check(step < 0.05, "P9 écart sous BrickDelay")
local sorted = true
for i = 2, #order do
	if many[order[i]].bottom < many[order[i - 1]].bottom then
		sorted = false
	end
end
check(sorted, "P10 les 60 triées du bas vers le haut")
order, rest, step = Plan.plan({ { bottom = 0, volume = 1 } }, 60, 0.05, 0.2, 2.5)
check(#order == 1 and near(step, 0.05), "P11 une seule pièce")
order, rest, step = Plan.plan({}, 60, 0.05, 0.2, 2.5)
check(#order == 0 and #rest == 0, "P12 aucune pièce")
local stand = {}
for i = 1, 15 do
	stand[i] = { bottom = i, volume = 1 }
end
order, rest, step = Plan.plan(stand, ShopBuild.StandMaxPieces, ShopBuild.Fallback.PieceDelay, ShopBuild.Fallback.DropTime, ShopBuild.MaxDuration)
check(#order == 15 and near(step, 0.09) and near(14 * step + 0.2, 1.46), "P13 présentoir de 15 pièces : 0,09 s d'écart, environ 1,5 s (L-297)")

-- Hauteur des clics
check(Plan.pitch(1, 2 ^ (1 / 12), 2) == 1, "S1 premier clic : hauteur d'origine")
check(near(Plan.pitch(2, 2 ^ (1 / 12), 2), 2 ^ (1 / 12)), "S2 un demi-ton par clic")
check(near(Plan.pitch(13, 2 ^ (1 / 12), 2), 2) and Plan.pitch(40, 2 ^ (1 / 12), 2) == 2, "S3 au plus une octave (PitchMax)")

-- Achat reconnu
check(Plan.isPurchase(3, 4, 2) and Plan.isPurchase(3, 5, 2), "A1 niveau +1 ou +2 : achat")
check(not Plan.isPurchase(nil, 4, 2), "A2 depuis rien (chargement du profil) : pas un achat")
check(not Plan.isPurchase(3, 9, 2), "A3 saut de 6 : pas un achat")
check(not Plan.isPurchase(4, 3, 2) and not Plan.isPurchase(4, 4, 2), "A4 baisse ou égal (renaissance) : pas un achat")
check(not Plan.isPurchase("3", 4, 2), "A5 valeur non numérique : pas un achat")
local stands = Plan.newStands(4, 0, 1)
check(#stands == 1 and stands[1] == 5, "N1 niveau 0 → 1 : DisplayStand_05")
stands = Plan.newStands(4, 2, 4)
check(#stands == 2 and stands[1] == 7 and stands[2] == 8, "N2 niveau 2 → 4 : 07 et 08")
check(string.format(ShopBuild.StandFormat, 5) == "DisplayStand_05" and string.format(ShopBuild.LookFormat, 3) == "Look_3", "N3 noms de Clément")

-- Config : repli = L-297
local F = ShopBuild.Fallback
check(F.StartDelay == 0.3 and F.PieceDelay == 0.09 and F.BrickDelay == 0.05 and F.DropTime == 0.2, "C1 délais de L-297")
check(F.DropHeight == 3.5 and F.DropJitter == 0.6 and F.DropTilt == 0.5 and F.BackOvershoot == 1.9, "C2 chute de L-297")
check(ShopBuild.EmitFallback.Bills == 18 and ShopBuild.EmitFallback.Puff == 3 and ShopBuild.EmitFallback.Sparks == 16, "C3 EmitCount de L-297")
check(ShopBuild.MaxPieces == 60 and ShopBuild.MaxDuration == 2.5, "C4 étage : 60 pièces, 2,5 s (V0 L-297 Q1)")
check(ShopBuild.Enabled == true and ShopBuild.PopSound == "UI_Click" and ShopBuild.FxName == "FX_ShopUpgrade_Build", "C5 interrupteur, son et effet")
check(not pcall(function()
	ShopBuild.Enabled = false
end), "C6 Config gelée")

-- Contrat
local spec = Models.ShopBuildFx
check(spec ~= nil and table.find(Models.List, spec) ~= nil, "K1 fiche ShopBuildFx dans Models.List")
local allOptional = spec ~= nil
for _, part in (spec and spec.Parts or {}) do
	if not part.Optional then
		allOptional = false
	end
end
check(allOptional and spec.Names[1] == "FX_ShopUpgrade_Build", "K2 FX_ShopUpgrade_Build : tout facultatif")

print(string.format("banc a406 plan : %d vérification(s), %d échec(s)", CHECKS, FAILS))

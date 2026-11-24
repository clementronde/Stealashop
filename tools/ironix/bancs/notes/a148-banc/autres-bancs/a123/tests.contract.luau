--!nocheck
-- G. a148 (vague 42, L-145 (d)) : le ContractChecker attend ENV_Event_FortuneVault et le tag FortuneVaultSpawn
-- (jamais un problème : « pas encore livré ») ; livré, LootSpawn_01 à _08 facultatifs (orange), Attachment ou
-- pièce, et à l'intérieur de la boîte du modèle (orange sinon).

setFeature("TruckEvent", false)
local Checker = serverModule("ContractChecker")
startServer() -- le ContractChecker tourne au Start, en Studio

local function lines(pattern)
	local out = {}
	for _, line in LOG do
		if string.find(line.text, "[Contrat]", 1, true) and string.find(line.text, pattern, 1, true) then
			table.insert(out, line)
		end
	end
	return out
end
local function problems()
	for _, line in LOG do
		local n = string.match(line.text, "%[Contrat%] Contrat : (%d+) problème")
		if n then
			return tonumber(n)
		end
		if string.find(line.text, "[Contrat] Contrat : OK", 1, true) then
			return 0
		end
	end
	return nil
end
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end

section("G1. Rien de livré")
local pendingVault = lines("pas encore livrés : ENV_Event_FortuneVault")
check(#pendingVault == 1 and pendingVault[1].kind == "PRINT", "G1a modèle attendu : « pas encore livré » (jamais rouge)")
local tagLine = lines("Tags pas encore posés")
check(#tagLine == 1 and string.find(tagLine[1].text, "FortuneVaultSpawn", 1, true) ~= nil and tagLine[1].kind == "PRINT", "G1b tag FortuneVaultSpawn attendu, « pas encore posé »")
local base = problems()
check(base ~= nil, `G1c rapport complet ({base} problème(s) sans rapport avec la Fortune Tower)`)

section("G2. Livré : LootSpawn manquants et hors de la boîte")
local template = make("Model", { Name = "ENV_Event_FortuneVault" })
local floor = make("Part", { Name = "Floor", Anchored = true, Size = Vector3.new(20, 2, 12), CFrame = CFrame.new(0, 1, 0) }, template)
template.PrimaryPart = floor
make("Part", { Name = "Window", Anchored = true, Size = Vector3.new(20, 10, 0.5), CFrame = CFrame.new(0, 7, -5.75) }, template)
make("Attachment", { Name = "HealthBarPoint", CFrame = CFrame.new(0, 14, 0) }, floor)
make("Highlight", { Name = "OutlineHighlight" }, template)
for i = 1, 5 do
	make("Attachment", { Name = string.format("LootSpawn_%02d", i), CFrame = CFrame.new(-8 + i * 2, 1, 2) }, floor)
end
make("Attachment", { Name = "LootSpawn_06", CFrame = CFrame.new(0, 1, -20) }, floor) -- devant, hors de la boîte
template.Parent = ASSETS:FindFirstChild("Events")
rerun()
local missing = lines("LootSpawn_07, LootSpawn_08 introuvable(s)")
check(#missing == 1 and missing[1].kind == "WARN", "G2a LootSpawn_07 et _08 absents : une ligne orange")
local outside = lines("LootSpawn_06 est hors de la boîte du modèle")
check(#outside == 1 and outside[1].kind == "WARN", "G2b LootSpawn_06 hors de la boîte : une ligne orange")
check(#lines("LootSpawn_01 est hors") == 0, "G2c un point à l'intérieur : rien à dire")
check(problems() == base, `G2d aucun problème de plus (orange seulement) : {problems()} contre {base}`)
check(#lines("pas encore livrés : ENV_Event_FortuneVault") == 0, "G2e livré : plus annoncé « pas encore livré »")

section("G3. Complet, un point en pièce")
template.Floor:FindFirstChild("LootSpawn_06").CFrame = CFrame.new(4, 1, 2)
make("Attachment", { Name = "LootSpawn_07", CFrame = CFrame.new(6, 1, 2) }, floor)
make("Part", { Name = "LootSpawn_08", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(8, 2.5, 2) }, template)
rerun()
check(#lines("LootSpawn") == 0, "G3a LootSpawn_01 à _08 à l'intérieur, Attachment ou pièce : rien à dire")
check(problems() == base, "G3b aucun problème de plus")

section("G4. Point d'apparition posé")
local spawnPoint = make("Part", { Name = "FortuneSpawn", Anchored = true, CanCollide = false, Size = Vector3.one, CFrame = CFrame.new(700, 0.5, 0) }, MAP)
addTag(spawnPoint, "FortuneVaultSpawn")
rerun()
local tags = lines("Tags pas encore posés")
check(#tags == 0 or string.find(tags[1].text, "FortuneVaultSpawn", 1, true) == nil, "G4a FortuneVaultSpawn posé : plus annoncé")
summary("scénario contrat de la Fortune Tower")

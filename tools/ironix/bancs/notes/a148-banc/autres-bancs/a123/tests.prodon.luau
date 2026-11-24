--!nocheck
-- E. Hors Studio, Features.FortuneTower = true : sans modèle de Clément, pas de vitrine (pas de bloc V0) ;
-- avec ENV_Event_FortuneVault : copie sans script, ancrée, butin sur LootSpawn_NN.

setFeature("FortuneTower", true)
setFeature("TruckEvent", false)
local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local FortuneTower = sharedModule("Config/FortuneTower")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(-40, 3, 0))
spawnCharacter(B, Vector3.new(-40, 3, 4))

section("E1. Sans modèle")
advance(FortuneTower.SpawnIntervalMax + 2, 1)
check(#vaults() == 0, "E1a aucune vitrine")
check(logHas("ENV_Event_FortuneVault introuvable", "WARN", "prod"), "E1b une ligne : modèle introuvable")
check(not logHas("bloc V0", nil, "prod"), "E1c pas de bloc V0 hors Studio")
-- a148 (vague 42, L-145 (a)) : interrupteur à true, jeu publié sans le modèle : rien, une seule ligne orange, aucune erreur.
advance(2 * FortuneTower.SpawnIntervalMax, 5)
check(#vaults() == 0 and #fortuneDrops() == 0, "E1d a148 : toujours rien après deux autres intervalles")
check(logCount("[FortuneTowerService]", "WARN", "prod") == 1, `E1e a148 : une seule ligne orange du service ({logCount("[FortuneTowerService]", "WARN", "prod")})`)
check(#notifies("Fortune") == 0, "E1f a148 : aucune annonce")

section("E2. Avec le modèle de Clément")
local template = make("Model", { Name = "ENV_Event_FortuneVault" })
local root = make("Part", { Name = "Root", Anchored = false, Size = Vector3.new(30, 1, 10), CFrame = CFrame.new(0, 0.5, 0), PivotOffset = CFrame.new(0, -0.5, 0) }, template)
template.PrimaryPart = root
make("Part", { Name = "Window", Anchored = false, Size = Vector3.new(28, 18, 0.5), CFrame = CFrame.new(0, 10, -4.75) }, template)
make("Attachment", { Name = "HealthBarPoint", CFrame = CFrame.new(0, 20, 0) }, root)
for i = 1, 8 do
	make("Attachment", { Name = string.format("LootSpawn_%02d", i), CFrame = CFrame.new(-14 + i * 3, -0.5, -12) }, root)
end
make("Highlight", { Name = "OutlineHighlight", Enabled = true }, template)
make("Script", { Name = "Evil" }, template)
template.Parent = ASSETS:FindFirstChild("Events")
local deadline = now() + FortuneTower.SpawnIntervalMax + 2
while currentVault() == nil and now() < deadline do
	advance(1, 1)
end
local vault = currentVault()
check(vault ~= nil, "E2a une vitrine")
check(vault and vault.Name == "FortuneVault" and vault:FindFirstChild("Evil") == nil, "E2b copie renommée, script retiré")
check(vault and vault.Root.Anchored == true and vault.Window.Anchored == true, "E2c toutes les pièces ancrées")
check(template.Parent ~= nil and template:FindFirstChild("Evil") ~= nil, "E2d le modèle de Clément n'est pas touché")
check(Workspace:GetAttribute("FortuneTest") == nil, "E2e (aucun crochet posé)")

section("E3. Casse : butin sur LootSpawn_NN")
moveTo(A, Vector3.new(678, 3, 0))
giveTool(A, "Hammer")
Tool.damage[A] = FortuneTower.MaxHP
fireAs(A, "HitWindow", vault:GetAttribute("WindowId"))
advance(0.2)
check(vault.OutlineHighlight.Enabled == false, "E3a contour éteint")
local expected = {}
for i = 1, 8 do
	expected[string.format("%02d", i)] = vault:FindFirstChild(string.format("LootSpawn_%02d", i), true).WorldPosition
end
local drops = fortuneDrops()
local ok = #drops == 8
for _, model in drops do
	local payload, position = Carry.GetDrop(model:GetAttribute("DropId"))
	local want = expected[string.match(payload.SlotId, "(%d%d)$")]
	if want == nil or math.abs(position.X - want.X) > 1e-3 or math.abs(position.Z - want.Z) > 1e-3 or math.abs(position.Y) > 1e-3 then
		ok = false
	end
end
check(ok, "E3b 8 colis, chacun sur son LootSpawn_NN, au sol")
summary("scénario hors Studio à true")

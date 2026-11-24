---------------------------------------------------------------- a128 (vague 39, 2026-11-14)
-- Scénario « rainbow » : collé après les scénarios du banc a17-carry (copie a128, sans leur bilan), même place
-- et même CarryController démarré. Correction 3 de perf-telephone.md : un modèle tagué CarryRainbow sans rien
-- à colorer n'est plus relu à chaque image, et la boucle d'image ne tourne pas ; ce qui arrive après le tag
-- est coloré dès son arrivée.
section("a128. Arc-en-ciel : rien à colorer, rien à faire")
flush()
check(RENDER_STEPPED:ConnectionCount() == 0, "a128 : aucune boucle d'image au départ")
local empty = make("Model", { Name = "SecretSansTeinte" }, Workspace)
make("Part", { Name = "Body", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 1, 80), Anchored = true }, empty)
local scans = 0
local realDescendants = empty.GetDescendants
rawset(empty, "GetDescendants", function(self)
	scans += 1
	return realDescendants(self)
end)
CollectionService:AddTag(empty, "CarryRainbow")
flush()
check(scans == 1, `a128 tag posé : modèle lu une fois ({scans})`)
check(RENDER_STEPPED:ConnectionCount() == 0, "a128 rien à colorer : aucune boucle d'image (avant : une, à chaque image)")
for _ = 1, 30 do
	RENDER_STEPPED:Fire(1 / 60)
	flush()
end
check(scans == 1, `a128 30 images plus tard : jamais relu ({scans}, avant : 31)`)
local lateTint = make("Part", { Name = "Tint", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 1, 80), Anchored = true, Color = band.Color }, empty)
flush()
check(RENDER_STEPPED:ConnectionCount() == 1, "a128 pièce Tint arrivée après le tag (streaming) : boucle branchée")
advance(0.2)
RENDER_STEPPED:Fire(1 / 60)
flush()
check(lateTint.Color == expectedRainbow(now()), "a128 la pièce arrivée après coup prend l'arc-en-ciel à l'image suivante")
check(scans == 1, "a128 toujours sans relecture du modèle")
-- Le faux Roblox n'a pas RemoveTag : le modèle sort du jeu (streaming), le tag s'en va avec lui.
empty.Parent = nil
flush()
check(RENDER_STEPPED:ConnectionCount() == 0, "a128 modèle sorti du jeu (tag retiré) : boucle débranchée")
make("Part", { Name = "Tint", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 1, 80), Anchored = true }, empty)
flush()
check(RENDER_STEPPED:ConnectionCount() == 0, "a128 après le retrait : une pièce qui arrive ne rebranche rien")
-- Le modèle revient (tag de nouveau annoncé) : relu une fois, ses deux pièces Tint colorées.
empty.Parent = Workspace
flush()
check(RENDER_STEPPED:ConnectionCount() == 1 and scans == 2, `a128 modèle revenu : relu une fois, boucle rebranchée ({scans})`)
advance(0.3)
RENDER_STEPPED:Fire(1 / 60)
flush()
local allTints = true
for _, d in empty:GetChildren() do
	if d.Name == "Tint" and not (d.Color == expectedRainbow(now())) then
		allTints = false
	end
end
check(allTints, "a128 ses deux pièces Tint à la couleur de l'arc-en-ciel")
empty:Destroy()
flush()
check(RENDER_STEPPED:ConnectionCount() == 0, "a128 modèle détruit : rien ne reste branché")

---------------------------------------------------------------- bilan
print(string.format("%d vérification(s), %d échec(s)", CHECKS, FAILS))
print(string.format("scénario rainbow : %d vérification(s), %d échec(s)", CHECKS, FAILS))
if FAILS > 0 then
	print("Sortie des modules :")
	dumpLog()
end

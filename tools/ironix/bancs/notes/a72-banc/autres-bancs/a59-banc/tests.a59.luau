-- Banc a59 (vague 21, L-091 points 4 et 5) : plus de tapis de caisse CashPad, argent ramassé sur la plaque
-- CollectPad_xx de chaque présentoir. Faux Roblox et décor : copie a59 du banc a14 (autres-bancs/a14-banc,
-- preamble.luau = ses 257 premières lignes). Ce fichier : contrat, plaques posées après coup (rayons),
-- présentoir sans plaque, plaque retirée, cible du tuto, encaissement automatique, CashOut, gains hors ligne.

local DataService = requireModule(Services.DataService, "server")
local PlotService = requireModule(Services.PlotService, "server")
local DisplayService = requireModule(displayModule, "server")
DisplayService.Init()
local cashOuts = {}
DisplayService.OnCashOut(function(player, amount, source)
	table.insert(cashOuts, { player = player, amount = amount, source = source, t = now() })
end)
local function lastOut()
	return cashOuts[#cashOuts] or {}
end

print("== A. Contrat (Contract/Models, Contract/Tags, Net)")
local Models = requireModule(Shared.Contract.Models, "server")
local Tags = requireModule(Shared.Contract.Tags, "server")
local Definitions = requireModule(Shared.Net.Definitions, "server")
local padSpec, cashPad = nil, nil
for _, part in Models.Plot.Parts do
	if part.Name == "CollectPad_%02d" then
		padSpec = part
	elseif part.Name == "CashPad" then
		cashPad = part
	end
end
check(cashPad == nil, "Models.Plot : plus de CashPad")
local tagged = false
for _, spec in Tags.List do
	if spec.Tag == "CashPad" then
		tagged = true
	end
end
check(not tagged, "Tags : plus de tag CashPad (aucune ligne rouge s'il disparaît)")
check(padSpec ~= nil and padSpec.From == 1 and padSpec.To == 20 and padSpec.Min == 4 and padSpec.Class == "BasePart", "CollectPad_01 à _20, _01 à _04 obligatoires, BasePart")
local inside = {}
for _, p in (padSpec and padSpec.Inside) or {} do
	inside[p.Name] = p
end
check(inside.AmountGui ~= nil and inside.AmountGui.Class == "SurfaceGui" and not inside.AmountGui.Optional, "dedans : AmountGui (SurfaceGui) obligatoire")
check(inside.Amount ~= nil and inside.Amount.Class == "TextLabel" and not inside.Amount.Optional, "dedans : Amount (TextLabel) obligatoire")
check(inside.BurstPoint ~= nil and inside.BurstPoint.Class == "Attachment" and inside.BurstPoint.Optional == true, "dedans : BurstPoint (Attachment) facultatif")
local remote = nil
for _, def in Definitions.List do
	if def.Name == "CashCollect" then
		remote = def
	end
end
check(remote ~= nil and remote.Direction == "ServerToClient" and #remote.Args == 3, "remote CashCollect(plotIndex, slotIndex, amount), serveur vers clients")

print("== B. Présentoir sans plaque, plaque posée avec son rayon")
local plot1 = buildPlot(1)
local alice, aliceRoot = newPlayer("Alice", 1)
CLIENT_PLAYER = alice
local data = newProfile()
data.Upgrades.DisplaySlots = 1 -- 5 présentoirs : le 5e est dans Rayon_02, sans plaque pour l'instant
local can = give(data, "Z1_CanetteDeSoda") -- 1 $/s
local phone = give(data, "Z3_Smartphone") -- 300 $/s
data.Display = { ["1"] = can, ["5"] = phone }
DataService._load(alice, data)
PlotService._assign(alice, plot1)
check(alice:GetAttribute("Income") == 301, "Income = 301 $/s")
step(3.05)
local v1 = padValue(plot1, 1)
check(v1 ~= nil and v1 >= 600 and v1 <= 920, "présentoir 5 sans plaque : son argent va sur la plaque 1, au plus petit numéro (" .. tostring(padText(plot1, 1)) .. ")")
-- RayonService pose les plaques du rayon 2 (CollectPad_05 à _08) : trouvées au plus 5 s + 1 s après.
local pad5 = new("Part", { Name = "CollectPad_05", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(4.4, 0.12, 2.6), CFrame = CFrame.new(30, 0.36, -30) }, plot1)
new("TextLabel", { Name = "Amount", Text = "$0" }, new("SurfaceGui", { Name = "AmountGui" }, pad5))
step(6.1)
aliceRoot.CFrame = CFrame.new(PAD_X[1], 3.1, -30)
step(0.3)
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(2.3)
local v5 = padValue(plot1, 5)
check(v5 ~= nil and v5 >= 1500 and v5 <= 2800, "plaque 5 trouvée au plus 5 s après la recherche précédente : le smartphone remplit sa propre plaque (" .. tostring(padText(plot1, 5)) .. ")")
local v1b = padValue(plot1, 1)
check(v1b ~= nil and v1b <= 4, "la plaque 1 ne reçoit plus que la canette (" .. tostring(padText(plot1, 1)) .. ")")

print("== C. Cible du tuto : la plaque qui porte le plus d'argent")
local target = DisplayService.GetCollectTarget(alice)
check(target ~= nil and near(target.X, 30) and near(target.Z, -30), "GetCollectTarget : la plaque 5")
clearRemotes()
aliceRoot.CFrame = CFrame.new(30, 3.1, -30)
step(0.3)
check(lastOut().source == "Pad" and (lastOut().amount or 0) >= 290, "ramassage sur la plaque 5")
local fired = nil
for _, e in REMOTE_LOG do
	if e.name == "CashCollect" then
		fired = e
	end
end
check(fired ~= nil and fired.args[1] == 1 and fired.args[2] == 5 and fired.to == nil, "CashCollect(1, 5, montant) envoyé à tous")
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)

print("== D. Plaque retirée (rayon caché) : son argent repasse sur la plaque 1")
step(2)
pad5:Destroy()
step(3.1)
local v1c = padValue(plot1, 1)
check(v1c ~= nil and v1c >= 500, "plaque 5 détruite : le smartphone remplit de nouveau la plaque 1 (" .. tostring(padText(plot1, 1)) .. ")")
check(DisplayService.GetRegister(alice) >= v1c, "GetRegister : total des plaques (l'argent resté sur la plaque 5 compris)")

print("== E. CashOut (Api) et encaissement automatique")
local before = data.Cash
local amount = DisplayService.CashOut(alice)
check(amount > 0 and lastOut().source == "Api" and data.Cash == before + amount, "CashOut : toutes les plaques dans Cash (source Api)")
step(1.1)
local v1d = padValue(plot1, 1)
check(v1d ~= nil and v1d <= 340, "plaque 1 repartie de 0 (" .. tostring(padText(plot1, 1)) .. ")")
local baseAuto = DisplayService.HasAutoCollect
DisplayService.HasAutoCollect = function()
	return true
end
local n = #cashOuts
step(3.05)
check(#cashOuts >= n + 2 and lastOut().source == "Auto", "encaissement automatique : chaque seconde, source Auto")
check(padText(plot1, 1) == "$0", "plaques à « $0 » avec l'encaissement automatique")
DisplayService.HasAutoCollect = baseAuto

print("== F. Gains hors ligne : directement dans Cash")
local cash0, collected0 = data.Cash, alice:GetAttribute("CashCollected")
local register0 = DisplayService.GetRegister(alice)
check(DisplayService.AddOfflineEarnings(alice, 1234.7) == true, "AddOfflineEarnings accepté")
check(data.Cash == cash0 + 1234 and lastOut().source == "Offline" and lastOut().amount == 1234, "1 234 $ dans Cash (centimes perdus), source Offline")
check(alice:GetAttribute("CashCollected") == collected0 + 1234, "CashCollected monte : le client voit l'encaissement (OnCashOut)")
check(math.abs(DisplayService.GetRegister(alice) - register0) <= 1, "rien n'est posé sur les plaques")
local m = #cashOuts
check(DisplayService.AddOfflineEarnings(alice, 0.4) == true and #cashOuts == m, "moins de 1 $ : accepté, rien versé")
check(DisplayService.AddOfflineEarnings(alice, -5) == false and DisplayService.AddOfflineEarnings(alice, 0 / 0) == false, "montant négatif ou NaN : refusé")
local nobody = newPlayer("SansProfil", 7)
check(DisplayService.AddOfflineEarnings(nobody, 100) == false, "profil absent : refusé")

print("== G. Sortie")
check(not logHas("contrôle des plaques CollectPad", "WARN") and not logHas("mise à jour des plaques", "WARN"), "aucune erreur dans la boucle")
check(not logHas("CashPad", "WARN"), "aucun avertissement sur CashPad")

summary()

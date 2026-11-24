-- a275 (vague GC2, 23/11, audit a272 F2) : ajouté à la fin du fichier assemblé du banc a98 (mêmes aides, même faux
-- Roblox). Rang relu par GroupService:GetGroupsAsync : toutes les RankRefreshSeconds s et avant une commande s'il date de
-- plus de RankMaxAge s ; MinGroupRank = 255.
print("--- a275")
CHECKS, FAILS = 0, 0
do
	local AdminCfg = requireShared("Shared.Config.Admin")
	check("A0 MinGroupRank = 255, RankRefreshSeconds = 300, RankMaxAge = 60 (V0)", AdminCfg.MinGroupRank == 255 and AdminCfg.RankRefreshSeconds == 300 and AdminCfg.RankMaxAge == 60)
	-- Faux GroupService et fausse horloge (ajout pur).
	local CLOCK = 1000
	local realOs = os
	os = setmetatable({ clock = function() return CLOCK end }, { __index = realOs })
	local GROUPS, READS, WEBFAIL = {}, 0, false
	local baseGet = game.GetService
	game.GetService = function(self, name)
		if name == "GroupService" then
			return {
				GetGroupsAsync = function(_, userId)
					READS += 1
					if WEBFAIL then
						error("HTTP 500")
					end
					local r = GROUPS[userId]
					return if r then { { Id = 777, Name = "Studio", Rank = r } } else {}
				end,
			}
		end
		return baseGet(self, name)
	end
	local DELAYS = {}
	local baseDelay = fakeTask.delay
	fakeTask.delay = function(t, fn, ...)
		table.insert(DELAYS, { t = t, fn = fn, args = { ... } })
	end

	STUDIO = false
	RANKS = { Boss = 255, Dev = 254, Small = 10 }
	local boss = newPlayer("Boss")
	local dev = newPlayer("Dev")
	local small = newPlayer("Small")
	loadAdmin()
	check("A1 propriétaire (255) admin à l'arrivée", boss:GetAttribute("IsAdmin") == true)
	check("A2 rang 254 plus admin (MinGroupRank 255)", dev:GetAttribute("IsAdmin") == nil)
	check("A3 relecture programmée à 300 s", #DELAYS >= 1 and DELAYS[#DELAYS].t == 300, #DELAYS > 0 and DELAYS[#DELAYS].t or nil)
	local refresh = DELAYS[#DELAYS] and DELAYS[#DELAYS].fn

	local cash = DATA[boss].Cash
	fire(boss, "GiveCash", nil, 10)
	check("A4 commande à rang frais : aucun appel web", READS == 0 and DATA[boss].Cash == cash + 10, READS)

	CLOCK += 61
	GROUPS[boss.UserId] = 255
	fire(boss, "GiveCash", nil, 10)
	check("A5 rang lu il y a plus de 60 s : relu avant d'agir, toujours admin", READS == 1 and DATA[boss].Cash == cash + 20, READS)
	fire(boss, "GiveCash", nil, 10)
	check("A6 juste relu : pas de nouvel appel", READS == 1 and DATA[boss].Cash == cash + 30, READS)

	CLOCK += 61
	GROUPS[boss.UserId] = 100 -- rétrogradé pendant la session
	fire(boss, "GiveCash", nil, 10)
	check("A7 rétrogradé : commande refusée sans reconnexion", READS == 2 and DATA[boss].Cash == cash + 30, DATA[boss].Cash)
	check("A8 IsAdmin retiré", boss:GetAttribute("IsAdmin") == nil)
	check("A9 journal « n'est plus admin »", hasLog(`Boss ({boss.UserId}) : rang 100 relu, n'est plus admin`))
	local reads = READS
	fire(boss, "GiveCash", nil, 10)
	check("A10 plus admin : aucun appel web (spam d'un non-admin)", READS == reads)
	fire(small, "GiveCash", nil, 10)
	check("A11 membre de rang 10 : aucun appel web", READS == reads)

	-- Relecture périodique : Dev passe à 255, Boss revient.
	GROUPS[dev.UserId] = 255
	GROUPS[boss.UserId] = 255
	local n = #DELAYS
	if refresh then
		refresh()
	end
	check("A12 relecture périodique : Dev devient admin", dev:GetAttribute("IsAdmin") == true)
	check("A13 relecture périodique : Boss redevient admin", boss:GetAttribute("IsAdmin") == true)
	check("A14 la relecture se reprogramme", #DELAYS == n + 1 and DELAYS[#DELAYS].t == 300)
	check("A15 journal « devient admin »", hasLog(`Dev ({dev.UserId}) : rang 255 relu, devient admin`))

	-- Web en panne : le rang d'avant reste.
	CLOCK += 61
	WEBFAIL = true
	local devCash = DATA[dev].Cash
	reads = READS
	fire(dev, "GiveCash", nil, 5)
	check("A16 web en panne : relecture tentée, rang gardé, commande faite", READS == reads + 1 and DATA[dev].Cash == devCash + 5)
	check("A17 avertissement « pas relu »", hasLog("rang de Dev dans le groupe 777 pas relu"))
	WEBFAIL = false



	game.GetService = baseGet
	fakeTask.delay = baseDelay
	os = realOs
	STUDIO = true
end
print(`banc a275-admin : {CHECKS} vérification(s), {FAILS} échec(s)`)

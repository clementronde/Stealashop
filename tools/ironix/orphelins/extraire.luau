--!nocheck
-- Extraction pour tools/ironix/orphelins.sh (check-up a417, P4) : sort, une par ligne et séparées par des
-- tabulations, les choses que le script cherche ensuite dans src/ :
--   REMOTE   <nom>  <ClientToServer|ServerToClient>
--   FEATURE  <nom>
--   CONFIG   <module>  <clé>            clé de premier niveau du module de Config
--   CONFIG   <module>  <clé>.<sous-clé> sous-clé d'une table de réglages (clés en texte, au moins une valeur simple)
--   TAG      <nom>                      tag du contrat (Contract/Tags)
-- Le faux Roblox et charge() sont dans ../commun/charge.luau, placé avant ce fichier.

local function out(...)
	print(table.concat({ ... }, "\t"))
end

for _, r in charge("Net/Definitions").List do
	out("REMOTE", r.Name, r.Direction)
end

for nom in charge("Config/Features") do
	out("FEATURE", nom)
end

for _, t in charge("Contract/Tags").List do
	out("TAG", t.Tag)
end

-- Une table de réglages : clés toutes en texte, au moins une valeur simple (nombre, texte, booléen) ;
-- pas une liste ni une table indexée par des Id (ById, ZoneOdds…), dont les clés sont des données.
local function reglages(t)
	if type(t) ~= "table" or getmetatable(t) ~= nil or #t > 0 then
		return false
	end
	local simple = false
	for k, v in t do
		if type(k) ~= "string" then
			return false
		end
		if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
			simple = true
		end
	end
	return simple
end

local modules = {}
for path in SOURCES do
	local nom = string.match(path, "^Config/(.+)$")
	if nom and nom ~= "DeepFreeze" and nom ~= "Features" then
		table.insert(modules, nom)
	end
end
table.sort(modules)
for _, nom in modules do
	local ok, module = pcall(charge, "Config/" .. nom)
	if not ok then
		out("ERREUR", `Config/{nom} ne se charge pas hors de Roblox : {module}`)
	elseif type(module) == "table" then
		for k, v in module do
			if type(k) == "string" then
				out("CONFIG", nom, k)
				-- Tables dont les clés sont des données (chances, migrations, écrans…) : pas des réglages.
				local donnees = string.find(k, "Odds$") or string.find(k, "Weights$") or string.find(k, "Chances$") or string.find(k, "^Migration") or string.find(k, "Screens$") or string.find(k, "ById$")
				if not donnees and reglages(v) then
					for sk in v do
						out("CONFIG", nom, k .. "." .. sk)
					end
				end
			end
		end
	end
end

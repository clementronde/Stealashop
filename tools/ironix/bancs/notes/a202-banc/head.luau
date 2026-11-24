--!nocheck
-- a202 : outils des scénarios de la cinématique.
function revealsOf(p)
	return remotes("RevealStarted", function(e)
		return e.args[1] == p
	end)
end
function lastReveal(p)
	local list = revealsOf(p)
	return list[#list]
end
function endedFor(id)
	return remotes("RevealEnded", function(e)
		return e.args[1] == id
	end)
end
function protected(p)
	return p:GetAttribute("RevealProtected") == true
end
-- Ouvre le rayon `n` (chance `luck` si donnée) : renvoie le colis et le RevealStarted envoyé (ou nil).
function startReveal(p, store, n, luck)
	local before = #revealsOf(p)
	local box = openBox(p, store, n, luck)
	local list = revealsOf(p)
	return box, if #list > before then list[#list] else nil
end
function revealDone(p, id)
	fireAs(p, "RevealDone", id)
	flush()
end
function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.1)
		t += 0.1
	end
	return fn()
end
-- Aucun attribut de l'ouverture d'avant sur le colis (a204).
function noShelfAttrs(box)
	for _, name in { "ShelfOpenState", "ShelfOpenBy", "ShelfOpenAt", "ShelfLuck", "ShelfRevealAt" } do
		if box:GetAttribute(name) ~= nil then
			return false
		end
	end
	return true
end

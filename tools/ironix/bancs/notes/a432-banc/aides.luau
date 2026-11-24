--!nocheck
---------------------------------------------------------------- banc a432 : aides communes des scénarios
-- Serveur et client lancés, Ada dans sa boutique : (ada, InventoryController du client).
function a432Start()
	advance(1000)
	startServer()
	local ada = join("Ada", nil)
	advance(1.5)
	buildInventoryUi(ada)
	buildHotbarUi(ada)
	startClient(ada)
	advance(0.5)
	return ada, clientModule("InventoryController")
end
-- La pièce d'aperçu BoxGhost est-elle dans le monde ? (et laquelle)
function ghostShown()
	for _, child in Workspace:GetChildren() do
		if child.Name == "BoxGhost" then
			return true, child
		end
	end
	return false, nil
end
-- Écart à plat (X, Z) entre deux points.
function xzDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
-- Le dernier Notify reçu par ce joueur (nil : aucun).
function lastNotify(player)
	local list = notifies(player)
	return list[#list]
end

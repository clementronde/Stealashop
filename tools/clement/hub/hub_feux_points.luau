-- Points des feux d'artifice de la zone safe (L-371 ; Clément, session de test du 2026-11-25 : « que les feux d'artifice
-- soient dans le vrai jeu, au pied de la zone safe, sur les coins, à gauche et à droite, et que tout le monde voie qu'un
-- joueur a récupéré un objet »). Noms et place validés par le chef VFX (2026-11-25) ; l'effet FX_Fireworks est fait par
-- la session « Auras et trails », qui écrira la ligne de liaison pour Cantin (points et effet ensemble).
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relancer refait la même chose.
-- Deux Parts dans Map/Hub/Zones, FireworksPoint_N et FireworksPoint_S : 1 stud, invisibles et ancrées, sans collision,
-- requête ni toucher, aucun script ; tag FireworksPoint, attribut texte Side = "N" ou "S" (plus clair que gauche et
-- droite, qui changent selon d'où l'on regarde). Posées sur le haut des deux piliers de la sortie (GatePost_N_Cap et
-- GatePost_S_Cap, dessus à 23,4) : les deux coins de l'entrée de la zone safe, là où passe le joueur qui revient avec un
-- objet ; d'en haut, les tirs se voient de plus loin. (Au pied des piliers, côté couloir, les points tombaient dans le
-- mur de terre EN/ES.) UpVector vertical (sens du tir), LookVector vers la place (-X). Le code clone l'effet sur le
-- CFrame de chaque point.
local CS = game:GetService("CollectionService")
local hub = workspace.Map.Hub
local zones = hub.Zones
local out = {}
for _, c in zones:GetChildren() do if CS:HasTag(c, "FireworksPoint") then c:Destroy() end end
for _, side in { "N", "S" } do
	local cap = hub.Walls:FindFirstChild("GatePost_" .. side .. "_Cap")
	assert(cap, "GatePost_" .. side .. "_Cap introuvable dans Map/Hub/Walls")
	local pos = Vector3.new(cap.Position.X, cap.Position.Y + cap.Size.Y / 2 + 0.5, cap.Position.Z)
	local p = Instance.new("Part"); p.Name = "FireworksPoint_" .. side
	p.Size = Vector3.new(1, 1, 1); p.Anchored = true; p.Transparency = 1
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0))
	p:SetAttribute("Side", side)
	CS:AddTag(p, "FireworksPoint")
	p.Parent = zones
	table.insert(out, string.format("%s : (%.1f ; %.1f ; %.1f)", p.Name, pos.X, pos.Y, pos.Z))
end
return table.concat(out, "\n")

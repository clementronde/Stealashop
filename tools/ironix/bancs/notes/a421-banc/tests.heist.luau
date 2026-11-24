-- a421 (L-316) : HeistController pendant la cinématique d'ouverture (Features.SingleBoxReveal) : le serveur ne pose
-- aucun ShelfOpenState sur le colis ; il pose RevealId sur le colis et RevealProtected sur l'ouvreur. Faux Roblox du
-- banc a104 ; arbre Shared complet (chaque module de src/shared).

---------------------------------------------------------------- arbre du jeu
local Shared = folder(ReplicatedStorage, "Shared")
for key in SOURCES do
	local path = string.match(key, "^shared/(.+)%.luau$")
	if path then
		local parent = Shared
		local parts = string.split(path, "/")
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		moduleScript(parent, parts[#parts], key)
	end
end
NET = { open = {}, grab = {} }
local netModule = Shared:FindFirstChild("Net") and Shared.Net:FindFirstChild("Net")
if netModule then
	netModule:Destroy()
end
moduleScript(Shared:FindFirstChild("Net") or folder(Shared, "Net"), "Net", {
	value = {
		Client = {
			OpenShelfBox = {
				Fire = function(_, id, step)
					table.insert(NET.open, { id = id, step = step })
				end,
			},
			GrabItem = {
				Fire = function(_, id, step)
					table.insert(NET.grab, { id = id, step = step })
				end,
			},
			HeistTimer = { Connect = function() end },
		},
	},
})
local Client = folder(newInstance("Folder"), "Client")
local Controllers = folder(Client, "Controllers")
local HeistModule = moduleScript(Controllers, "HeistController", "client/Controllers/HeistController.luau")

local function inst(class, parent, name, props)
	local o = newInstance(class)
	o.Name = name
	for k, v in props or {} do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- Joueur local, dans le magasin.
local player = inst("Player", PlayersService, "P1", { UserId = 1 })
PlayersService.LocalPlayer = player
inst("PlayerGui", player, "PlayerGui")
local character = inst("Model", Workspace, "P1")
inst("Part", character, "HumanoidRootPart", { CFrame = CFrame.new(0, 3, 3) })
player.Character = character

-- Magasin ouvert : Bounds, rayon, dossier ShelfBoxes.
local store = inst("Model", folder(Workspace, "Map"), "STORE_Test")
store:SetAttribute("HeistOpen", true)
inst("Part", store, "Bounds", { CFrame = CFrame.new(0, 5, 0), Size = Vector3.new(60, 10, 40), Transparency = 1 })
local shelf = inst("Part", store, "Shelf", { CFrame = CFrame.new(0, 0, 0), Size = Vector3.new(60, 0.2, 2) })
local function slotPos(n)
	return Vector3.new((n - 2) * 2, 0, 0) -- trois emplacements à 2 studs : tous à portée du joueur
end
for n = 1, 3 do
	inst("Attachment", shelf, string.format("ShelfSlot_%02d", n), { Position = slotPos(n) })
end
CollectionService:AddTag(store, "NPCStore")
local boxesF = folder(store, "ShelfBoxes")
local function makeBox(n)
	local box = newInstance("Model")
	box.Name = "Box_" .. n
	local body = inst("Part", box, "Body", { CFrame = CFrame.new(slotPos(n) + Vector3.new(0, 1, 0)), Size = Vector3.new(2, 2, 2) })
	box.PrimaryPart = body
	box:SetAttribute("SlotId", "STORE_Test/" .. n)
	box:SetAttribute("Slot", string.format("ShelfSlot_%02d", n))
	box:SetAttribute("BoxRarity", "Common")
	box:SetAttribute("Landed", true)
	CollectionService:AddTag(box, "ShelfBox")
	box.Parent = boxesF
	return box
end
local function promptOf(n)
	return shelf:FindFirstChild(string.format("ShelfSlot_%02d", n)):FindFirstChild("GrabPrompt")
end

local box1 = makeBox(1)
local box2 = makeBox(2)
makeBox(3)
local Heist = requireModule(HeistModule)
taskLib.spawn(Heist.Start)
advance(0.3)

print("== H. invites pendant la cinématique")
local p1, p2 = promptOf(1), promptOf(2)
check(p1 ~= nil and p2 ~= nil, "H0 (banc) invites « Open » posées")
if p1 and p2 then
	check(p1.Enabled == true and p2.Enabled == true, "H0 (banc) invites actives (magasin ouvert, dedans, mains vides)")
	-- L'ouvreur appuie : invite coupée 1 s en attendant le serveur (comportement d'avant).
	p1.Triggered:Fire(player)
	check(#NET.open == 1 and NET.open[1].step == "End", "H1 (banc) OpenShelfBox « End » envoyé")
	check(p1.Enabled == false, "H1 invite coupée tout de suite après l'appui")
	-- Réponse du serveur (nouveau déroulé) : RevealId sur le colis, RevealProtected sur l'ouvreur ; aucun ShelfOpenState.
	advance(0.1)
	box1:SetAttribute("RevealId", "R1")
	player:SetAttribute("RevealProtected", true)
	advance(1 / 60)
	check(p2.Enabled == false and promptOf(3).Enabled == false, "H2 ouvreur en cinématique : plus aucune invite, même sur les colis voisins")
	advance(1.2)
	check(p1.Enabled == false, "H3 plus d'invite sur le colis ouvert après le délai d'1 s (cinématique en cours)")
	check(p2.Enabled == false, "H3b toujours aucune invite voisine pour l'ouvreur")
	advance(3)
	check(p1.Enabled == false and p2.Enabled == false, "H3c … pendant toute la cinématique")
	-- Spectateur : protection levée (la sienne n'a jamais existé), colis encore marqué.
	player:SetAttribute("RevealProtected", nil)
	advance(1 / 60)
	check(p2.Enabled == true and promptOf(3).Enabled == true, "H4 protection levée : invites voisines rendues tout de suite")
	advance(0.3)
	check(p1.Enabled == false, "H5 colis encore marqué RevealId : pas d'invite, pour personne")
	-- Fin : marque retirée (fin propre sans le colis, cas de garde du serveur).
	box1:SetAttribute("RevealId", nil)
	advance(0.3)
	check(p1.Enabled == true, "H6 marque retirée : invite rendue (rien de bloqué pour toujours)")
	-- Cas normal : le colis disparaît, un colis neuf arrive sur le rayon.
	box1:SetAttribute("RevealId", "R2")
	advance(0.3)
	box1:Destroy()
	advance(0.3)
	check(promptOf(1) == nil, "H7 colis retiré : son invite est partie")
	makeBox(1)
	advance(0.3)
	local fresh = promptOf(1)
	check(fresh ~= nil and fresh.Enabled == true, "H8 rayon rempli : invite du colis neuf active")
	-- L'autre colis n'a jamais été bloqué par la marque d'un voisin.
	box2:SetAttribute("RevealId", "R3")
	advance(0.3)
	check(p2.Enabled == false and fresh.Enabled == true and promptOf(3).Enabled == true, "H9 seule l'invite du colis marqué est coupée")
end
check(errorsInLog() == 0, "H10 aucune erreur des contrôleurs")

--!nocheck
-- T. La batte en slot 2 (ToolService) : donnée à chaque apparition juste après l'outil de casse,
-- jamais avant ; un outil acheté reprend le slot 1 ; attribut BatTool, jamais ToolId ; faite de
-- TOOL_Batte ; HitController et WindowService ne la prennent pas pour un outil de casse.

local Tool = serverModule("ToolService")
local Data = serverModule("DataService")
local Bat = sharedModule("Config/Bat")
startServer()

-- Hotbar de Roblox simulée : un outil qui arrive prend le premier slot libre ; il le garde entre
-- le Backpack et la main ; détruit (ou parti ailleurs), il le libère. Nouveau Backpack : tout repart.
local slots = {}
local watched = {}
local function hotbarFor(player)
	local function release(tool)
		for i = 1, 10 do
			if slots[i] == tool then
				slots[i] = nil
			end
		end
	end
	local function assign(tool)
		if not tool:IsA("Tool") or table.find(slots, tool) then
			return
		end
		for i = 1, 10 do
			if slots[i] == nil then
				slots[i] = tool
				break
			end
		end
		tool.AncestryChanged:Connect(function()
			local parent = tool.Parent
			if parent ~= player.Character and parent ~= player:FindFirstChild("Backpack") then
				release(tool)
			end
		end)
	end
	local function watchBackpack(backpack)
		if watched[backpack] then
			return
		end
		watched[backpack] = true
		table.clear(slots)
		backpack.ChildAdded:Connect(assign)
		for _, child in backpack:GetChildren() do
			assign(child)
		end
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(child)
		end
	end)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		watchBackpack(backpack)
	end
end

section("T. Profil pas encore chargé : ni outil ni batte")
local A = newPlayer("Alice", false)
hotbarFor(A)
spawnCharacter(A, Vector3.new(60, 3, 0))
flush()
check(#A.Backpack:GetChildren() == 0, "T1 profil pas chargé : rien dans le Backpack (jamais la batte avant l'outil de casse)")
local profile = newProfile()
Data._load(A, profile)
flush()
check(slots[1] and slots[1]:GetAttribute("ToolId") == "Fists", "T2 profil chargé : l'outil de casse en slot 1")
check(slots[2] and slots[2]:GetAttribute("BatTool") == true, `T3 la batte en slot {Bat.HotbarSlot}`)
local bat = slots[2]
check(bat.Name == "Bat" and bat.ToolTip == "Bat" and bat.CanBeDropped == false, "T4 nommée Bat, ne se lâche pas")
check(bat:GetAttribute("ToolId") == nil, "T5 aucun attribut ToolId sur la batte")
check(
	bat.RequiresHandle == true and bat:FindFirstChild("Handle") ~= nil and bat:FindFirstChild("Body") ~= nil and bat:FindFirstChild("HitPoint", true) ~= nil,
	"T6 faite de TOOL_Batte (Handle, Body, Band, HitPoint)"
)
check(bat.Handle.Massless == true and bat.Handle.CanCollide == false and bat.Body.Anchored == false, "T7 pièces préparées comme un outil (sans masse, sans collision)")
check(#BAT_ASSET:GetChildren() == 3 and BAT_ASSET.Handle:FindFirstChild("HitPoint") ~= nil and BAT_ASSET.Parent == TOOLS_FOLDER, "T8 le modèle de Clément n'est pas touché")
check(#A.Backpack:GetChildren() == 2, "T9 deux outils, pas un de plus")

section("T'. Main, réapparition, achat d'outil")
equipBat(A)
flush()
check(Tool.IsHoldingBat(A) and not Tool.IsHoldingTool(A), "T10 batte en main : IsHoldingBat, pas IsHoldingTool")
equipCasse(A)
flush()
check(Tool.IsHoldingTool(A) and not Tool.IsHoldingBat(A), "T11 outil de casse en main : l'inverse")
check(slots[1]:GetAttribute("ToolId") == "Fists" and slots[2] == bat, "T12 les slots ne bougent pas en passant d'une main à l'autre")
spawnCharacter(A, Vector3.new(60, 3, 0))
flush()
check(slots[1] and slots[1]:GetAttribute("ToolId") == "Fists" and slots[2] and slots[2]:GetAttribute("BatTool") == true, "T13 réapparition : outil de casse en slot 1, batte en slot 2")
check(slots[2] ~= bat and isDestroyed(bat), "T14 nouvelle batte, l'ancienne est partie avec l'ancien Backpack")
check(#A.Backpack:GetChildren() == 2, "T15 toujours deux outils")
bat = slots[2]
Tool.Grant(A, "Wrench")
check(Tool.Equip(A, "Wrench"), "T16 achat et Equip de la clé à molette")
flush()
check(slots[1] and slots[1]:GetAttribute("ToolId") == "Wrench", "T17 la clé à molette reprend le slot 1")
check(slots[2] == bat and not isDestroyed(bat), "T18 la batte garde le slot 2 (même Tool)")
check(#A.Backpack:GetChildren() == 2, "T19 toujours deux outils")
equipBat(A)
Tool.Grant(A, "Crowbar")
Tool.Equip(A, "Crowbar")
flush()
check(Tool.IsHoldingBat(A) and slots[1]:GetAttribute("ToolId") == "Crowbar" and slots[2] == bat, "T20 Equip pendant que la batte est en main : elle reste en main, en slot 2")
Data._load(A, profile) -- profil rechargé (OnProfileLoaded) : rien en double
flush()
check(#A.Backpack:GetChildren() + (if Tool.IsHoldingBat(A) then 1 else 0) == 2, "T21 profil rechargé : rien en double")

section("T''. Ni HitController ni WindowService ne la prennent pour un outil de casse")
local B = newPlayer("Bob")
spawnCharacter(B, Vector3.new(65, 3, 27.75), Vector3.new(0, 0, 1))
flush()
startClient(B)
local window = STORE_A:FindFirstChild("Window")
local windowId = window:GetAttribute("WindowId")
local maxHP = window:GetAttribute("MaxHP")
local batB = equipBat(B)
flush()
local hitsBefore = #serverCalls("HitWindow")
batB.Activated:Fire()
advance(0.5)
check(#serverCalls("HitWindow") == hitsBefore, "T22 clic avec la batte devant une vitrine : aucun HitWindow (HitController l'ignore)")
check(#serverCalls("SwingBat") == 1, "T23 c'est un SwingBat (BatController)")
clearLog()
fireAs(B, "HitWindow", windowId)
flush()
check(logHas("outil de casse pas en main", "WARN") and window:GetAttribute("Broken") ~= true, "T24 HitWindow avec la batte en main : refusé par WindowService")
local casse = equipCasse(B)
flush()
advance(0.2)
hitsBefore = #serverCalls("HitWindow")
casse.Activated:Fire()
advance(0.5)
check(#serverCalls("HitWindow") == hitsBefore + 1, "T25 l'outil de casse, lui, frappe toujours (HitController)")
check(window:GetAttribute("Broken") == true and maxHP == 27, "T26 vitrine de zone 1 (27 PV, a134) cassée en un coup de 101")

summary("scénario tool")

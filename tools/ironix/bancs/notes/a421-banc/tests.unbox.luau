--!nocheck
-- a421 (L-316) : RevealController + Reveal/Unbox : dès le début de la scène, plus rien du vrai colis à son ancienne
-- place (contour Highlight, arêtes SelectionBox sur la pièce invisible Outline, étiquette, décalque, contour d'une autre
-- forme ou ajouté pendant la scène), même si ShelfBoxController les rallume ; tout est remis à la fin.
-- Mise en place du banc client a257 (début de son tests.client.luau repris).

-- Faux Roblox d'a68 : classes réelles absentes de sa liste (SelectionBox est un GuiBase3d, Texture un Decal).
do
	local EXTRA = { SelectionBox = { "PVAdornment", "GuiBase3d" }, BoxHandleAdornment = { "HandleAdornment", "PVAdornment", "GuiBase3d" }, Texture = { "Decal" } }
	local baseIsA = Methods.IsA
	function Methods.IsA(self, class)
		if baseIsA(self, class) then
			return true
		end
		for _, c in EXTRA[rawget(self, "_class")] or {} do
			if c == class then
				return true
			end
		end
		return false
	end
end

local alice = newPlayer("Alice")
local function spawn(player, position)
	local character = spawnCharacter(player, position)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.HipHeight = 2
	make("Animator", { Name = "Animator" }, humanoid)
	local hand = make("Part", { Name = "RightHand", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position + Vector3.new(1, 0, 0)), CanCollide = false }, character)
	make("Attachment", { Name = "RightGripAttachment", CFrame = CFrame.new(0, -0.2, 0) }, hand)
	return character
end
spawn(alice, Vector3.new(65, 3, -50))
make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
make("ScreenGui", { Name = "UI_Escape", Enabled = true }, alice.PlayerGui)
local unboxScreen = make("ScreenGui", { Name = "UI_Unbox", Enabled = false }, alice.PlayerGui)
make("ImageLabel", { Name = "EdgeGlow", ImageTransparency = 1, ImageColor3 = Color3.new(1, 1, 1) }, unboxScreen)
Workspace.CurrentCamera = CAMERA
CAMERA.FieldOfView = 70
CAMERA.CameraType = Enum.CameraType.Custom
CAMERA.CameraSubject = alice.Character:FindFirstChildOfClass("Humanoid")
CAMERA.CFrame = CFrame.lookAt(Vector3.new(65, 8, -25), Vector3.new(65, 3, -45))
dropRig()
startClient(alice)
local RC = clientModule("RevealController")

local PLAN = "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37"
local function scene(id)
	for _, s in RC.GetState().Scenes do
		if s.Id == id then
			return s
		end
	end
	return nil
end

-- Le vrai colis du rayon (BOX1, tag ShelfBox) : tout ce qui peut le dessiner hors de ses pièces.
local outline = make("Highlight", { Name = "OutlineHighlight", Enabled = true, FillTransparency = 1, OutlineTransparency = 0 }, BOX1)
local edgesPart = make("Part", { Name = "Outline", Transparency = 1, Size = Vector3.new(2.02, 1.62, 2.02), CFrame = BOX1.CFrame }, BOX1)
local edges = make("SelectionBox", { Name = "OutlineBox", Visible = true }, edgesPart)
edges.Adornee = edgesPart
local label = make("BillboardGui", { Name = "BB_Box", Enabled = true }, BOX1)
local decal = make("Decal", { Name = "Sticker", LocalTransparencyModifier = 0 }, BOX1)
local future = make("Highlight", { Name = "FX_Outline", Enabled = true, FillTransparency = 1, OutlineTransparency = 0 }, edgesPart) -- autre forme (L-305)

section("O. Ouverture : plus rien du vrai colis sur le rayon")
NET.Server.RevealStarted:FireAll(alice, STORES[1].Name, STORES[1].Name .. "/03", ITEM_A.Id, "Rare", "", 4.5, 1, "Small", "o1", PLAN)
flush()
advance(1 / 30)
local s = scene("o1")
check(s ~= nil and s.Unbox ~= nil, "O0 (banc) scène de l'ouvreur avec la nouvelle ouverture")
check(BOX1.LocalTransparencyModifier == 1, "O1 colis du rayon caché (comme avant)")
check(edges.Visible == false, "O2 arêtes noires (SelectionBox OutlineBox de la pièce Outline) éteintes dès le début")
check(outline.Enabled == false and label.Enabled == false, "O3 contour OutlineHighlight et étiquette BB_Box éteints (comme avant)")
check(future.Enabled == false, "O4 contour d'une autre forme (FX_Outline, L-305) éteint aussi")
check(decal.LocalTransparencyModifier == 1, "O5 décalque du colis caché")
-- ShelfBoxController (ou un autre) les rallume : rééteints à l'image suivante.
outline.Enabled = true
edges.Visible = true
label.Enabled = true
advance(1 / 30)
check(outline.Enabled == false and edges.Visible == false and label.Enabled == false, "O6 rallumés par un autre : rééteints à l'image suivante")
local late = make("Highlight", { Name = "LateOutline", Enabled = true }, BOX1)
local lateBox = make("SelectionBox", { Name = "LateEdges", Visible = true }, BOX1)
advance(1 / 30)
check(late.Enabled == false and lateBox.Visible == false, "O7 contour ajouté pendant la scène : éteint aussi")
advance(1)
check(edges.Visible == false and outline.Enabled == false and future.Enabled == false, "O8 toujours éteints pendant l'ouverture")

section("F. Fin : tout est remis")
NET.Server.RevealEnded:FireAll("o1")
flush()
advance(1 / 30)
check(scene("o1") == nil, "F0 (banc) scène finie")
check(edges.Visible == true and lateBox.Visible == true, "F1 arêtes remises (colis encore là : rien de caché pour toujours)")
check(outline.Enabled == true and future.Enabled == true and late.Enabled == true and label.Enabled == true, "F2 contours et étiquette rendus (ShelfBoxController reprend la main)")
check(decal.LocalTransparencyModifier == 0, "F3 décalque remis")
summary("scénario unbox")

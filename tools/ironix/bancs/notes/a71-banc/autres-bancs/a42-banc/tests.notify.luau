--!nocheck
-- N. Notifications (L-071, point 8) : bandeau de secours tant que UI_Notify manque (pastille entière
-- à gauche, texte après elle, séparés), messages répétés comptés « ×2 », au plus 3 à la fois, retirés
-- au bout de HOLD s ; puis branchement du contrat 2.2 quand UI_Notify arrive (copie du Template, Label).

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
startClient(alice)
local Notify = clientModule("NotifyController")
local Motion = requireModule(CONTROLLERS.UI.Motion, "client")
-- Copie d'a62 (2026-11-11, vague 22, L-092 3d) : durée d'un message = UiMotion.Toast.Hold (2,4 s) quand
-- NotifyController la lit, sinon 4 s comme avant : bonne avant et après la fusion.
local HOLD = 4
do
	local notifySource = SOURCES["client/Controllers/NotifyController.luau"] or ""
	local motionSource = SOURCES["shared/Config/UiMotion.luau"] or ""
	local hold = string.match(motionSource, "Toast = {.-Hold = ([%d%.]+)")
	if string.find(notifySource, "UiMotion.Toast.Hold", 1, true) and hold then
		HOLD = tonumber(hold) :: number
	end
end

local heard = {}
Notify.OnNotify(function(message, kind)
	table.insert(heard, { message = message, kind = kind })
end)

local function shown()
	return Notify.GetShown()
end
local function toasts()
	local gui = alice.PlayerGui:FindFirstChild("NotifyV0")
	local out = {}
	if gui then
		for _, child in gui.Stack:GetChildren() do
			if child.Name == "Toast" then
				table.insert(out, child)
			end
		end
	end
	return out
end

section("N. Bandeau de secours (UI_Notify pas livré)")
serverFire("Notify", alice, "Caught! Recommended speed: 22", "Warning")
local gui = alice.PlayerGui:FindFirstChild("NotifyV0")
check(gui ~= nil and gui:IsA("ScreenGui") and gui.ResetOnSpawn == false, "N1 bandeau de secours NotifyV0 dans le PlayerGui")
local list = toasts()
check(#list == 1 and list[1].Visible, "N2 un bandeau visible")
local toast = list[1]
check(toast.Label.Text == "Caught! Recommended speed: 22", `N3 le message ({toast.Label.Text})`)
check(#heard == 1 and heard[1].kind == "Warning", "N4 OnNotify : les écouteurs reçoivent le message et sa catégorie")
check(logHas("[Notify Warning] Caught! Recommended speed: 22", "PRINT", "client"), "N5 en Studio, le message est aussi dans la sortie")

section("N'. Mise en page : la pastille n'est pas coupée, le texte ne la touche pas")
local stack = gui.Stack
check(stack.AnchorPoint.Y == 1 and stack.Position.Y.Scale >= 0.5, "N6 en bas de l'écran (rien d'important en haut, 2.2)")
check(toast.Size.Y.Offset >= 44 and toast.Size.Y.Scale == 0, `N7 bandeau de {toast.Size.Y.Offset} px de haut (au moins 44)`)
local icon = toast.Icon
local iconLeft = icon.Position.X.Offset - icon.AnchorPoint.X * icon.Size.X.Offset
local iconRight = iconLeft + icon.Size.X.Offset
check(icon.Position.X.Scale == 0 and iconLeft >= 8, `N8 pastille entière dans le bandeau, à {iconLeft} px du bord gauche`)
check(icon.Size.Y.Offset <= toast.Size.Y.Offset - 8 and icon.AnchorPoint.Y == 0.5 and icon.Position.Y.Scale == 0.5, "N9 pastille centrée en hauteur, plus petite que le bandeau")
check(toast.ClipsDescendants ~= true, "N10 rien n'est rogné")
local label = toast.Label
local labelLeft = label.Position.X.Offset
check(label.Position.X.Scale == 0 and labelLeft >= iconRight + 10, `N11 texte {labelLeft - iconRight} px après la pastille (pas collé)`)
check(label.Size.X.Scale == 1 and label.Size.X.Offset <= -(labelLeft + 10), "N12 le texte s'arrête avant le bord droit")
check(label.TextXAlignment == "Enum.TextXAlignment.Left" and label.TextScaled and label.TextWrapped, "N13 texte aligné à gauche, réduit et coupé en lignes pour tenir")
local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
check(constraint ~= nil and constraint.MaxTextSize == 20 and constraint.MinTextSize >= 10, "N14 taille du texte bornée")
check(icon.Glyph.Text == "!" and icon.Glyph.Size == UDim2.fromScale(1, 1), "N15 « ! » dans la pastille (Warning), qui la remplit")
local widthLimit = toast:FindFirstChildOfClass("UISizeConstraint")
check(widthLimit ~= nil and widthLimit.MaxSize.X == 560, "N16 bandeau de 560 px de large au plus")

section("N''. Catégories, répétitions, limite")
serverFire("Notify", alice, "Your Soda Can is back on its stand!", "Info")
list = toasts()
local info = list[2]
check(#list == 2 and info.Icon.Glyph.Text == "i", "N17 Info : « i »")
check(info.LayoutOrder > toast.LayoutOrder, "N18 le plus récent vient après (ordre d'arrivée)")
advance(HOLD / 2)
serverFire("Notify", alice, "Caught! Recommended speed: 22", "Warning")
list = toasts()
check(#list == 2 and toast.Label.Text == "Caught! Recommended speed: 22 ×2", `N19 même message encore affiché : compté, pas répété ({toast.Label.Text})`)
advance(HOLD / 2 + 0.5)
list = toasts()
check(#list == 1 and list[1] == toast, `N20 {HOLD} s après : l'autre message est parti, le message répété reste (sa durée est repartie)`)
advance(HOLD / 2 + 0.5)
check(#toasts() == 0 and #shown() == 0, `N21 {HOLD} s après sa répétition : parti lui aussi`)
for i = 1, 4 do
	serverFire("Notify", alice, `Message {i}`, "Announce")
end
list = toasts()
local texts = {}
for _, entry in shown() do
	table.insert(texts, entry.Text)
end
check(#list == 3 and #shown() == 3 and texts[1] == "Message 2" and texts[3] == "Message 4", `N22 au plus 3 à la fois : le plus ancien part ({table.concat(texts, ", ")})`)
check(list[1].Icon.BackgroundColor3 == Color3.fromHex("#FFC21A"), "N23 Announce : pastille or")
advance(HOLD + 0.2)
check(#toasts() == 0, "N24 tous partis")

section("N'''. UI_Notify livré : copie du Template")
local starter = buildNotifyUi(StarterGui)
local screen = copyScreen(alice, starter)
serverFire("Notify", alice, "The truck exploded: grab the boxes!", "Info")
check(alice.PlayerGui:FindFirstChild("NotifyV0") == nil, "N25 le bandeau de secours est retiré")
local template = screen.List.Template
local copies = {}
for _, child in screen.List:GetChildren() do
	if child ~= template and child:IsA("Frame") then
		table.insert(copies, child)
	end
end
check(#copies == 1 and copies[1].Visible and copies[1].Label.Text == "The truck exploded: grab the boxes!", "N26 une copie du Template, visible, Label = le message")
check(screen.Enabled == true, "N27 écran allumé au premier message")
check(template.Visible == false and template.Label.Text == "Example", "N28 le Template reste caché et inchangé")
check(copies[1].Icon.Image == "rbxassetid://123", "N29 Icon de Clément gardé tel quel")
check(Motion.GetState(copies[1]) ~= nil, "N30 montré par Motion.Show")
serverFire("Notify", alice, "The truck exploded: grab the boxes!", "Info")
check(copies[1].Label.Text == "The truck exploded: grab the boxes! ×2", "N31 répété : « ×2 » sur la copie")
serverFire("Notify", alice, "The truck drove away.", "Info")
local second = nil
for _, child in screen.List:GetChildren() do
	if child ~= template and child ~= copies[1] and child:IsA("Frame") then
		second = child
	end
end
check(second ~= nil and second.LayoutOrder > copies[1].LayoutOrder, "N32 deuxième message : une deuxième copie, après la première")
advance(HOLD + 0.5)
local left = 0
for _, child in screen.List:GetChildren() do
	if child ~= template and child:IsA("GuiObject") then
		left += 1
	end
end
check(left == 0, `N33 au bout de {HOLD} s : copies retirées`)
check(#heard == 10, `N34 tous les messages sont passés aux écouteurs ({#heard})`)

section("N''''. UI_Notify sans Template : bandeau de secours, un avertissement")
screen:Destroy()
local broken = buildNotifyUi(alice.PlayerGui, false)
serverFire("Notify", alice, "Night is falling: hurry home!", "Warning")
check(#toasts() == 1, "N35 sans Template : bandeau de secours")
check(logCount("UI_Notify sans Template (contrat 2.2) : messages dans le bandeau de secours", "WARN", "client") == 1, "N36 un avertissement en Studio")
serverFire("Notify", alice, "Dawn!", "Info")
check(logCount("UI_Notify sans Template", "WARN", "client") == 1, "N37 une seule fois")
broken:Destroy()

summary("scénario notifications")

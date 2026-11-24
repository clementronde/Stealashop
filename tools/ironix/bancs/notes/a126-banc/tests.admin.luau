--!nocheck
-- Scénario « admin » du banc a126 (vague 38, L-135 point 3, Clément : « code ») : AdminButton caché pendant le dialogue
-- du receleur (UI_PawnShop.Dialog), remontré à la fin (vrais PawnShopController et AdminController) ; le bouton BASE
-- n'existe plus : HudController ne lit plus ReturnBaseButton (laissé tel quel, aucun avertissement), contrat sans lui.

local HUD = buildHud(PLAYER_GUI) -- a encore ReturnBaseButton (avec Cooldown « 84s »), comme un écran pas encore nettoyé
local ADMIN = addAdminButton(HUD)
local PAWN = buildPawnShop(PLAYER_GUI)
local stall = makeStall("ENV_Hub_PawnStall", "PawnShop", Vector3.new(-40, 3.95, 0), true)
local pad = stall:FindFirstChild("ShopPad")
local base = HUD:FindFirstChild("ReturnBaseButton", true)
local cooldown = base:FindFirstChild("Cooldown")
local baseVisible = base.Visible
P1:SetAttribute("IsAdmin", true)
startClient()
local Pawn = clientModule("PawnShopController")
local Admin = clientModule("AdminController")
local UI = sharedModule("Contract/UI")

section("contrat UI : plus de ReturnBaseButton")
local found = false
for _, screen in UI.Screens do
	for _, element in screen.Elements do
		if string.find(element.Path, "ReturnBaseButton", 1, true) then
			found = true
		end
	end
end
check(not found, "aucun élément ReturnBaseButton dans Contract/UI")

section("HUD : ReturnBaseButton plus lu")
P1:SetAttribute("ReturnBaseReadyAt", serverTime() + 60)
advance(0.3)
check(base.Visible == baseVisible and cooldown.Text == "84s" and cooldown.Visible == true, "ReturnBaseButton et Cooldown laissés tels quels")
check(not logHas("ReturnBaseButton", "WARN", "client"), "aucun avertissement sur ReturnBaseButton")

section("AdminButton : admin, montré")
check(type(Admin.SetHidden) == "function", "AdminController.SetHidden existe")
check(ADMIN.Visible == true, "IsAdmin : AdminButton montré")

section("dialogue du receleur : AdminButton caché, puis remontré")
moveTo(Vector3.new(pad.Position.X, 3.1, pad.Position.Z))
Pawn.Open(pad)
advance(0.2)
check(Pawn.GetState().Open == true, "dialogue ouvert")
check(ADMIN.Visible == false, "pendant le dialogue : AdminButton caché")
P1:SetAttribute("IsAdmin", false)
advance(0.1)
P1:SetAttribute("IsAdmin", true)
advance(0.1)
check(ADMIN.Visible == false, "IsAdmin reposé pendant le dialogue : toujours caché")
Pawn.Leave(pad)
advance(0.2)
check(Pawn.GetState().Open == false and ADMIN.Visible == true, "dialogue fermé (descendu de la plaque) : AdminButton remontré")

section("fermeture en s'éloignant")
Pawn.Open(pad)
advance(0.2)
check(ADMIN.Visible == false, "rouvert : caché")
moveTo(FAR_SPOT)
advance(0.3)
check(Pawn.GetState().Open == false and ADMIN.Visible == true, "parti loin : dialogue fermé, AdminButton remontré")

section("joueur non admin : jamais montré")
P1:SetAttribute("IsAdmin", false)
advance(0.1)
moveTo(Vector3.new(pad.Position.X, 3.1, pad.Position.Z))
Pawn.Open(pad)
advance(0.2)
Pawn.Leave(pad)
advance(0.2)
check(ADMIN.Visible == false, "non admin : AdminButton reste caché après le dialogue")

section("SetHidden : plusieurs raisons")
P1:SetAttribute("IsAdmin", true)
advance(0.1)
Admin.SetHidden("A", true)
Admin.SetHidden("B", true)
Admin.SetHidden("A", false)
check(ADMIN.Visible == false, "une raison reste : caché")
Admin.SetHidden("B", false)
check(ADMIN.Visible == true, "plus aucune raison : montré")

check(not logHas("SetHidden", "WARN", "client"), "aucune erreur de SetHidden")
check(not logHas("ERREUR", nil, "client"), "aucune erreur")
summary("scénario admin")

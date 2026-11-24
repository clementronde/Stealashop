---------------------------------------------------------------- scénario « item » (a154, vague 46) : objet ramené en zone safe
local S = UiMotionC.SafeFlash
local Definitions = requireModule(ReplicatedStorage.Shared.Net.Definitions, "client")

print("\n== I0. Remote ItemSecured et textes V0")
local def, rank, last = nil, nil, #Definitions.List
for r, entry in Definitions.List do
	if entry.Name == "ItemSecured" then
		def, rank = entry, r
	end
end
check(def ~= nil and def.Direction == "ServerToClient" and #def.Args == 1 and def.Args[1].Name == "itemId" and def.Args[1].Kind == "string", "I0a ItemSecured(itemId) du serveur vers le client")
-- Fusion 45 : les remotes ajoutés après lui par les vagues suivantes (a152 : TakeDisplayItem) peuvent le suivre.
local LATER = { TakeDisplayItem = true, RedeemCode = true, CodeResult = true, Rebirth = true, LockShop = true, ClaimWeekly = true, CatchScene = true, RevealStarted = true, RevealEnded = true, RevealDone = true, PlaceFromReserve = true, BubbleSpawn = true, BubbleGone = true, ClaimBubble = true, Announce = true } -- a254 : annonces au serveur ; a214 : bulles ×N du tapis ; a206 : réserve des présentoirs ; a202 : cinématique d'ouverture ; a192 : capture mise en scène ; a162 : codes cadeaux ; a164 : renaissance ; a159 : verrou de la boutique ; a166 : coffre hebdomadaire
local after = true
for r = (rank or last) + 1, last do
	after = after and LATER[Definitions.List[r].Name] == true
end
check(rank ~= nil and after, "I0b ajouté à la fin de Net/Definitions (seuls des remotes plus récents le suivent)")
check(S.ItemTitle == "Item secured!" and S.ItemSubtitle == "%s %s", "I0c textes V0 « Item secured! » et « <Rareté> <Nom> »")

local escapeGui = makeEscape()
local banner, flash = escapeGui.Banner, escapeGui.Flash
local title, subtitle, icon = banner.Title, banner.Subtitle, banner.BoxIcon
local snap = snapshot(escapeGui)
requireModule(CHASE_MODULE, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)
local cam = Workspace.CurrentCamera
local base = cam.FieldOfView
new("Decal", { Name = "ICON_BOX_Rare", Texture = "rbxassetid://box-rare" }, ICONS_FOLDER)

print("\n== I1. Objet Rare sans icône livrée (Smartphone) : par le remote ItemSecured")
local NetServer = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local soundsBefore = #SOUNDS_PLAYED
NetServer.Server.ItemSecured:Fire(P1, "Z3_Smartphone")
step(1 / 60)
check(Feel.GetEscapeState().Count == 1 and Feel.GetEscapeState().Kind == "Escape", "I1a une arrivée jouée, une seule")
check(escapeGui.Enabled == true and flash.BackgroundTransparency < 0.2, "I1b UI_Escape allumé, flash")
check(title.Text == "Item secured!", `I1c Title « Item secured! » ({title.Text})`)
check(subtitle.Text == "Rare Smartphone", `I1d Subtitle « Rare Smartphone » ({subtitle.Text})`)
check(icon.Image == "rbxassetid://box-rare", `I1e BoxIcon = ICON_BOX_Rare, rareté du catalogue ({icon.Image})`)
check(soundsSince(soundsBefore)[1] == "Heist_SafeFlash", "I1f son Heist_SafeFlash")
step(S.FovInTime)
check(cam.FieldOfView > base + S.FovAdd / 2, `I1g zoom vers + {S.FovAdd} ({cam.FieldOfView})`)
step(S.Hold + S.OutTime + 0.2)
check(escapeGui.Enabled == false and near(cam.FieldOfView, base, 1e-6), "I1h écran éteint, caméra rendue")
check(title.Text == "ESCAPED!" and subtitle.Text == "Take the box to your shop!", `I1i textes de Clément remis ({title.Text} / {subtitle.Text})`)
local same, why = sameAs(snap, escapeGui, { [escapeGui] = { Enabled = true }, [icon] = { Image = true } })
check(same, `I1j UI_Escape comme Clément l'a fait (sauf l'icône) ({why})`)
check(Feel.GetEscapeState().Count == 1, "I1k jouée une fois")

print("\n== I2. Objet avec son icône ICON_<ItemId>")
new("Decal", { Name = "ICON_Z3_Smartphone", Texture = "rbxassetid://smartphone" }, ICONS_FOLDER)
Feel.Escape(nil, nil, "Z3_Smartphone")
step(0.5)
check(icon.Image == "rbxassetid://smartphone", `I2a BoxIcon = icône de l'objet ({icon.Image})`)
step(S.Hold + S.OutTime + 0.2)

print("\n== I3. Colis : rien ne change")
Feel.Escape("Premium", "Rare")
step(0.5)
check(title.Text == "ESCAPED!" and subtitle.Text == "Take the box to your shop!", "I3a colis : textes de Clément")
check(icon.Image == "rbxassetid://box-rare", "I3b colis : ICON_BOX_<Rareté>")
step(S.Hold + S.OutTime + 0.2)

print("\n== I4. Objet inconnu du catalogue : arrivée de colis, textes de Clément")
Feel.Escape(nil, nil, "Inconnu")
step(0.5)
check(title.Text == "ESCAPED!" and escapeGui.Enabled == true, "I4a pas de texte passager")
step(S.Hold + S.OutTime + 0.2)
check(escapeGui.Enabled == false and anyUIScale(escapeGui) == nil, "I4b fini proprement")
summary()

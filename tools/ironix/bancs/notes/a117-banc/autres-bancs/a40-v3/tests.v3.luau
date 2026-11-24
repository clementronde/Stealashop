--!nocheck
-- Scénario « v3 » (a67, 2026-11-11, L-095 point 1) : IndexController sur une copie de UI_Index_v3
-- (prototype tools/clement/index_v3.luau) : cartes (Clip, silhouette), fiche Detail au clic, Rewards de la
-- zone visible, ZoneItem, catégories et onglets de mutation ; v2 et l'ancien UI_Index éteints ; repli sur
-- la v2 quand la v3 disparaît.

advance(1000)
startServer()
local Zones = sharedModule("Config/Zones")
local Format = sharedModule("Format")
local data = newProfile()
local found1 = { "Z1_CanetteDeSoda", "Z1_BoissonEnergisante", "Z1_BriqueDeLait", "Z1_PaquetDeChips", "Z1_Donut", "Z1_HotDog", "Z1_Banane", "Z1_Ananas", "Z1_Pasteque" }
for index, id in found1 do
	addItem(data, `c-{index}`, id, if index <= 4 then index else nil, 1, 500)
end
addItem(data, "c-z2", "Z2_YoYo", nil, 2, 500)
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local legacy = buildIndexGui(playerGui)
legacy.Enabled = true
local v2 = buildIndexV2Gui(playerGui)
v2.Enabled = true
local gui = buildIndexV3Gui(playerGui)
local hud = buildHud(playerGui)
local sounds = watchPops()
advance(1.5)
startClient(ada)

local window = gui.Root.Window
local list = window.ListPanel.List
local detail = window.Detail
local rewards = window.Rewards
local categories = gui.Root.Categories
local tabs = gui.Root.MutationTabs
local VIEW = Index.View
local BLACK = Color3.new(0, 0, 0)
local function silhouette(id)
	return Rarities.ById[Items.ById[id].Rarity].Color:Lerp(BLACK, VIEW.SilhouetteDarken)
end
local function income(zone, rarity)
	return `{Format.money(Formulas.ItemIncome(zone, rarity))}/s`
end

section("branchement")
check(logHas("[Loader Client] 1 module(s) démarré(s)", "PRINT", "client") and not logHas("[Loader Client]", "WARN"), "IndexController démarré sans erreur")
check(gui.Enabled == false and v2.Enabled == false and legacy.Enabled == false, "UI_Index_v3 fermé ; UI_Index_v2 et UI_Index éteints")
check(list.Template.Visible == false and v3AllCards(gui) == 0, "Template gardé caché, aucune carte avant l'ouverture")

section("ouverture : cartes, silhouettes, compteurs")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true and v2.Enabled == false and legacy.Enabled == false, "IndexButton ouvre UI_Index_v3, pas la v2 ni l'ancien")
check(v2AllCards(v2) == 0 and #cardsOf(legacy) == 0, "aucune carte dans les anciens écrans")
for zone = 1, Index.ZoneCount do
	local cards = v3Cards(gui, `Zone{zone}Section`)
	check(#cards == #Index.ByZone[zone], `zone {zone} : {#cards} cartes dans Zone{zone}Section.Content.Cards`)
end
check(v3AllCards(gui) == Index.Total, `{Index.Total} cartes en tout ({v3AllCards(gui)})`)
local soda = v3CardOf(gui, "Zone1Section", "Z1_CanetteDeSoda")
check(soda.Name == "Item_01_Z1_CanetteDeSoda" and soda.Visible and soda.LayoutOrder == 1, "carte nommée, rangée, visible")
check(soda.Icon.Image == ICON_TEXTURE.Z1_CanetteDeSoda and sameColor(soda.Icon.ImageColor3, Color3.new(1, 1, 1)), "trouvé : icône en couleurs")
check(textOf(soda, "ItemName") == "Soda Can", `trouvé : le nom (« {textOf(soda, "ItemName")} »)`)
check(sameColor(soda.Clip.BackgroundColor3, Rarities.ById.Common.Color), "trouvé : Clip à la couleur de la rareté")
check(sameColor(soda.Clip.Rays.ImageColor3, Rarities.ById.Common.Color) and sameColor(soda.Clip.Glow.ImageColor3, Rarities.ById.Common.Color), "Rays et Glow teints")
local carrot = v3CardOf(gui, "Zone1Section", "Z1_Carotte")
check(sameColor(carrot.Icon.ImageColor3, silhouette("Z1_Carotte")), "pas trouvé : silhouette = couleur de la rareté vers le noir (0,82)")
check(sameColor(carrot.Clip.BackgroundColor3, Rarities.ById.Common.Color:Lerp(BLACK, VIEW.ClipDarken)), "pas trouvé : Clip assombri (0,55)")
check(textOf(carrot, "ItemName") == "???" and carrot.Lock.Visible == false, "pas trouvé : « ??? », Lock reste caché")
local noodles = v3CardOf(gui, "Zone1Section", "Z1_PotDeNouilles")
check(sameColor(noodles.Clip.Rays.ImageColor3, Rarities.ById.Rare.Color) and sameColor(noodles.Icon.ImageColor3, silhouette("Z1_PotDeNouilles")), "Pot de nouilles : rayons Rare, silhouette Rare")
check(gui.Root.Window.ListPanel.List.Template.Clip.UIGradient.Color == V3_GRADIENT, "le Template garde son UIGradient")
check(textOf(window.UnlockedBar, "Counter") == "Unlocked: 10/83", `compteur : {textOf(window.UnlockedBar, "Counter")}`)
local z1 = list.Zone1Section
local z1Name = "MINI MART\nKIOSK" -- a73 (vague 24) : ZoneName = les magasins PNJ de la zone (Config/Zones.Stores)
check(textOf(z1, "ZoneName") == z1Name and textOf(z1, "ZoneCount") == "9/13", `zone 1 : « {textOf(z1, "ZoneName")} », « {textOf(z1, "ZoneCount")} »`)
check(near(z1.Content.ZoneBar.Fill.Size.X.Scale, 9 / 13), "Fill zone 1 : 9/13")
check(z1.Content.ZoneBar.ZoneItem.Image == ICON_TEXTURE.Z1_PotDeNouilles and sameColor(z1.Content.ZoneBar.ZoneItem.ImageColor3, silhouette("Z1_PotDeNouilles")), "ZoneItem zone 1 : le Pot de nouilles (Rare), en silhouette")
local z2Rarest = nil
for _, item in Index.ByZone[2] do
	if z2Rarest == nil or Rarities.ById[item.Rarity].Order >= Rarities.ById[z2Rarest.Rarity].Order then
		z2Rarest = item
	end
end
check(list.Zone2Section.Content.ZoneBar.ZoneItem.Image == ICON_TEXTURE[z2Rarest.Id], `ZoneItem zone 2 : {z2Rarest.Id}`)
check(list.SecretsSection.Visible == false and list.Zone1Section.Visible == true, "NORMAL : SecretsSection cachée")

section("fiche Detail : à l'ouverture, puis au clic")
check(textOf(detail, "DetailName") == "Soda Can" and textOf(detail, "DetailRarity") == "Common", "à l'ouverture : le 1er objet de la zone 1")
check(textOf(detail, "DetailIncome") == income(1, "Common"), `revenu : {textOf(detail, "DetailIncome")}`)
check(sameColor(detail.BackgroundColor3, Rarities.ById.Common.Color) and detail.UIGradient.Color == V3_DETAIL_GRADIENT, "fond à la couleur de la rareté, UIGradient de Clément")
check(popsOf("DetailIcon") == 0, "pas de DetailPop à l'ouverture")
click(carrot)
check(textOf(detail, "DetailName") == "???" and textOf(detail, "DetailIncome") == "???", "clic sur la Carotte (pas trouvée) : « ??? »")
check(sameColor(detail.IconFrame.DetailIcon.ImageColor3, silhouette("Z1_Carotte")) and detail.IconFrame.DetailIcon.Image == ICON_TEXTURE.Z1_Carotte, "DetailIcon en silhouette")
check(popsOf("DetailIcon", VIEW.DetailPop.From) == 1, "T.45 DetailPop : DetailIcon 0,82 → 1")
local yoyo = v3CardOf(gui, "Zone2Section", "Z2_YoYo")
click(yoyo)
check(textOf(detail, "DetailName") == "Yo-Yo" and textOf(detail, "DetailRarity") == "Uncommon" and textOf(detail, "DetailIncome") == income(2, "Uncommon"), `clic sur le Yo-yo : nom, rareté, revenu ({textOf(detail, "DetailIncome")})`)
check(sameColor(detail.DetailRarity.TextColor3, Rarities.ById.Uncommon.Color:Lerp(Color3.new(1, 1, 1), VIEW.RarityLighten)), "DetailRarity de la couleur de la rareté, éclaircie")
check(popsOf("DetailIcon", VIEW.DetailPop.From) == 2, "un DetailPop par clic")
check(countKeys(SERVER_CALLS) == 0, "rien n'est envoyé au serveur")

section("Rewards : la zone visible dans la liste")
check(rewards.Visible == true and textOf(rewards.SpeedReward, "Amount") == "+3%" and textOf(rewards.CashReward, "Amount") == "+" .. Format.money(Index.ZoneCash(1)), `zone 1 : « {textOf(rewards.SpeedReward, "Amount")} », « {textOf(rewards.CashReward, "Amount")} »`)
check(textOf(rewards.ClaimButton, "ClaimLabel") == "Claim!", "zone 1 pas complète : texte de Clément")
-- La liste défile : la section 2 passe en haut.
for index, name in V3_SECTIONS do
	list[name].AbsolutePosition = Vector2.new(0, 100 + (index - 2) * 400)
end
list.CanvasPosition = Vector2.new(0, 400)
check(textOf(rewards.CashReward, "Amount") == "+" .. Format.money(Index.ZoneCash(2)), "zone 2 en haut de la liste : sa prime")
check(popsOf("Rewards", VIEW.RewardsSwap.From) == 1, "T.46 RewardsSwap quand la zone change")
list.CanvasPosition = Vector2.new(0, 410)
check(popsOf("Rewards") == 1, "même zone : pas de nouveau RewardsSwap")
for index, name in V3_SECTIONS do
	list[name].AbsolutePosition = Vector2.new(0, 100 + (index - 1) * 400)
end
list.CanvasPosition = Vector2.new(0, 0)
check(textOf(rewards.CashReward, "Amount") == "+" .. Format.money(Index.ZoneCash(1)) and popsOf("Rewards") == 2, "retour en haut : zone 1")
local claim = rewards.ClaimButton
local soundsBefore = #sounds
click(claim)
check(sounds[#sounds] == "UI_Deny" and #sounds == soundsBefore + 1, "Claim sur une zone pas complète : son UI_Deny")
check(claim.Position ~= V3_CLAIM_POS, "le bouton tremble")
advance(0.5)
check(claim.Position == V3_CLAIM_POS, "puis revient à sa place")
for _, id in { "Z1_Carotte", "Z1_PotDeNouilles", "Z1_Brocoli", "Z1_EpiDeMais" } do
	IndexService.Discover(ada, id)
end
flush()
advance(10)
-- Copie a117 (vague 34, L-127 point 2) : la prime attend d'être réclamée ; Claim l'envoie au serveur.
check(textOf(z1, "ZoneCount") == "13/13" and textOf(rewards.ClaimButton, "ClaimLabel") == "Claim!", "zone 1 complète, prime pas encore réclamée : « Claim! » (a117)")
check(textOf(detail, "DetailName") == "Yo-Yo", "la fiche garde l'objet cliqué")
soundsBefore = #sounds
click(claim)
advance(0.5)
check(not table.find(sounds, "UI_Deny", soundsBefore + 1) and claim.Position == V3_CLAIM_POS, "Claim sur une zone complète : ni refus ni secousse")
check(textOf(rewards.ClaimButton, "ClaimLabel") == "Claimed!" and ada:GetAttribute("IndexClaimed") == "1", "réclamée : « Claimed! » (a117)")
check(sameColor(carrot.Icon.ImageColor3, Color3.new(1, 1, 1)) and textOf(carrot, "ItemName") == "Carrot", "la Carotte passe en couleurs")
check(z1.Content.ZoneBar.ZoneItem.ImageColor3 == Color3.new(1, 1, 1), "ZoneItem zone 1 en couleurs")

section("catégories")
POPS = {}
click(categories.SecretsButton)
check(list.SecretsSection.Visible == true and list.Zone1Section.Visible == false and list.Zone6Section.Visible == false, "SECRETS : SecretsSection seule")
check(categories.SecretsButton.Selected.Visible and not categories.NormalButton.Selected.Visible and not categories.MutationsButton.Selected.Visible, "Selected sur SECRETS")
check(rewards.Visible == false, "Rewards caché hors de NORMAL")
check(popsOf("Item_01_Secret_ChatPorteBonheurDore", 0) == 1 and #POPS == 1, `T.29 : la carte du Secret entre (0 → 1) ; {#POPS} carte(s)`)
local secret = v3CardOf(gui, "SecretsSection", "Secret_ChatPorteBonheurDore")
check(secret.Clip.UIGradient.Color.Keypoints[1].Value == Rarities.ById.Secret.RainbowColors[1] and #secret.Clip.UIGradient.Color.Keypoints == #Rarities.ById.Secret.RainbowColors, "carte du Secret : UIGradient arc-en-ciel")
IndexService.Discover(ada, "Secret_ChatPorteBonheurDore")
flush()
click(secret)
local low = Format.money(Formulas.ItemIncome(1, "Secret"))
local high = Format.money(Formulas.ItemIncome(#Zones, "Secret"))
check(textOf(detail, "DetailIncome") == `{low}-{high}/s`, `Secret : revenu de la zone 1 à la 6 ({textOf(detail, "DetailIncome")})`)
check(#detail.UIGradient.Color.Keypoints == #Rarities.ById.Secret.RainbowColors, "fiche du Secret : fond arc-en-ciel")
POPS = {}
click(categories.MutationsButton)
check(list.SecretsSection.Visible == false and list.Zone1Section.Visible == true and tabs.Visible == true and gui.Root.MutationCaption.Visible == true, "MUTATIONS : les zones, MutationTabs et MutationCaption")
check(textOf(gui.Root, "MutationCaption") == "Collect every item in SHINY!", "légende de l'onglet SHINY")
check(textOf(window.UnlockedBar, "Counter") == "Unlocked: 0/83" and textOf(z1, "ZoneCount") == "0/13", "pas d'index par mutation : compteurs à 0")
check(sameColor(soda.Icon.ImageColor3, silhouette("Z1_CanetteDeSoda")) and textOf(soda, "ItemName") == "???", "toutes les cartes en silhouette")
local cardPops, tabPops = 0, 0
for _, entry in POPS do
	if string.sub(entry.name, 1, 5) == "Item_" then
		cardPops += 1
	elseif string.match(entry.name, "Tab$") then
		tabPops += 1
	end
end
check(cardPops == VIEW.CardsIn.Max and tabPops == 7, `T.29 : {cardPops} cartes entrent (14 au plus), {tabPops} onglets`)
click(tabs.GoldTab)
check(tabs.GoldTab.Selected.Visible and not tabs.ShinyTab.Selected.Visible and textOf(gui.Root, "MutationCaption") == "Collect every item in GOLD!", "onglet GOLD choisi, légende à jour")
click(categories.NormalButton)
check(tabs.Visible == false and gui.Root.MutationCaption.Visible == false and rewards.Visible == true and list.Zone1Section.Visible, "retour à NORMAL : onglets cachés, Rewards revient")
check(textOf(soda, "ItemName") == "Soda Can" and textOf(window.UnlockedBar, "Counter") == "Unlocked: 15/83", `les cartes reviennent ({textOf(window.UnlockedBar, "Counter")})`)

section("fermeture, repli sur la v2, retour de la v3")
click(window.CloseButton)
check(gui.Enabled == false and v3AllCards(gui) == 0, "CloseButton ferme l'écran (cartes retirées)")
gui:Destroy()
flush()
click(hud.LeftRail.IndexButton)
check(v2.Enabled == true and v2AllCards(v2) == Index.Total and legacy.Enabled == false, "sans la v3 : UI_Index_v2 s'ouvre")
click(hud.LeftRail.IndexButton)
check(v2.Enabled == false, "et se ferme")
local gui2 = buildIndexV3Gui(playerGui)
flush()
check(gui2.Enabled == false and v2.Enabled == false, "UI_Index_v3 revient (ResetOnSpawn) : branché fermé, la v2 éteinte")
local v2again = buildIndexV2Gui(nil)
v2again.Enabled = true
v2again.Parent = playerGui
flush()
check(v2again.Enabled == false, "une v2 recréée après la v3 reste éteinte")
click(hud.LeftRail.IndexButton)
check(gui2.Enabled == true and v3AllCards(gui2) == Index.Total and textOf(gui2.Root.Window.Detail, "DetailName") == "Golden Lucky Cat", "le bouton ouvre la v3 ; la fiche garde le dernier objet cliqué")

summary("scénario v3")

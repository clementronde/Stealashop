--!nocheck
-- Scénario « save » (vague 25) : disposition sauvegardée dans le profil (champ facultatif Hotbar, version
-- inchangée), relue au chargement : identifiant disparu (pas au joueur) = case vide côté serveur ; colis
-- posé ou objet exposé = case vide côté client ; ce qui est dans l'inventaire sans case y reste ; champ
-- abîmé = rien de sauvegardé ; sauvegarde puis nouvelle session : même disposition.

advance(1000)
startServer()
local DataService = serverModule("DataService")
local data = newProfile()
addItem(data, "high", "Z3_Smartphone", nil, 3, 1)
addItem(data, "low", "Z1_Banane", nil, 1, 2)
addItem(data, "shown", "Z1_Donut", 1, 1, 3)
data.Hotbar = { "Bat", "shown", "gone", "high", "Tool", "{11111111-2222-3333-4444-555555555555}" }
local ada = join("Ada", data)
advance(1.5)
local version = dataOf(ada).Version

section("chargement : identifiants disparus vidés par le serveur")
check(layoutText(dataOf(ada).Hotbar) == "Bat,shown,,high,Tool,", `profil nettoyé : {layoutText(dataOf(ada).Hotbar)}`)
check(ada:GetAttribute("HotbarLayout") == "Bat,shown,,high,Tool,", `attribut HotbarLayout : {ada:GetAttribute("HotbarLayout")}`)
local loaded = ada:GetAttribute("HotbarLayout")

section("client : objet exposé vidé, l'objet sans case reste dans l'inventaire")
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local function L()
	return layoutText(Hotbar.GetState().Layout)
end
check(Hotbar.GetState().Ready and L() == "Bat,,,high,Tool,", `disposition relue, objet exposé vidé : {L()}`)
check(slotsOf().Slot_Item_low == nil, "« low » (dans l'inventaire, sans case) n'est pas ajouté : pas nouveau")
check(slotsOf().Slot_Bat.LayoutOrder == 1 and slotsOf().Slot_Tool.LayoutOrder == 5, "batte en 1, outil en 5")
advance(1)
check(layoutText(dataOf(ada).Hotbar) == "Bat,,,high,Tool,", "le client renvoie sa disposition nettoyée")
check(dataOf(ada).Version == version, `version du profil inchangée ({version})`)

section("nouvelle chose : première case vide")
local box = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
advance(1)
check(L() == `Bat,{box},,high,Tool,`, `colis en case 2 : {L()}`)
check(layoutText(dataOf(ada).Hotbar) == L(), "gardé")

section("nouvelle session : même disposition")
local saved = table.clone(dataOf(ada).Hotbar)
local copy = table.clone(dataOf(ada))
copy.Hotbar = saved
leave(ada)
advance(1)
local again = join("Ada2", copy)
advance(1.5)
check(again:GetAttribute("HotbarLayout") == `Bat,{box},,high,Tool,`, `relu au retour : {again:GetAttribute("HotbarLayout")}`)

section("champ abîmé : comme rien de sauvegardé")
local broken = newProfile()
broken.Hotbar = "Tool,Bat"
local cy = join("Cy", broken)
advance(1.5)
check(cy:GetAttribute("HotbarLayout") == "" and dataOf(cy).Hotbar == nil, "texte au lieu d'une liste : attribut vide, champ retiré")
local short = newProfile()
short.Hotbar = { "Tool", "Tool", "Bat" }
local dee = join("Dee", short)
advance(1.5)
check(dee:GetAttribute("HotbarLayout") == "Tool,,Bat,,,", `liste courte avec un double : complétée, double vidé ({dee:GetAttribute("HotbarLayout")})`)

summary("scénario save")

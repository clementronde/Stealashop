--!nocheck
-- Copie d'a48 (DEV-102) : version attendue PROFILE_V = 6 quand Types/Profile a Offline (gains hors ligne), 5 sinon.
-- Copie d'a51 (L-089) : v7 quand Types/Profile a Spot (colis rangés par uid).
PROFILE_V = if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Spot: Spot?", 1, true) then 7 elseif string.find(SOURCES["shared/Types/Profile.luau"] or "", "Offline: Offline", 1, true) then 6 else 5
-- Scénario « migration » : Config/Index (zones, Secrets, bonus, Encode / Decode), profil v4 de DataService
-- (MIGRATIONS[4] : les objets déjà possédés sont découverts, inventaire, présentoirs et coffre-fort ;
-- ni les colis en attente ni les ItemId inconnus ; vieux profils v0, v1 lisibles ; Index abîmé ; profil
-- neuf ; profil trop récent), sauvegarde et retour, puis le filet d'IndexService au chargement (objet
-- possédé absent de l'Index d'un profil déjà en v4).

advance(1000) -- os.time() du banc loin de 0 : les dates de découverte se lisent
startServer()

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(logHas("[Loader Serveur] 15 module(s) démarré(s)", "PRINT", "server"), "15 modules serveur démarrés (IndexService compris)")
check(Features.Index == true, "Features.Index = true (pre.on)")
check(not logHas("[IndexService] Features.Index = false", nil, "server"), "pas de ligne « index fermé »")

section("Config/Index")
check(Index.Total == 83, `83 objets au catalogue, Secret compris ({Index.Total})`)
check(Index.ZoneCount == 6 and #Index.ByZone[1] == 13 and #Index.ByZone[2] == 16 and #Index.ByZone[3] == 14 and #Index.ByZone[4] == 15 and #Index.ByZone[5] == 12 and #Index.ByZone[6] == 12, "zones de 13, 16, 14, 15, 12 et 12 objets (10.5)")
check(#Index.Secrets == 1 and Index.Secrets[1].Id == "Secret_ChatPorteBonheurDore", "1 Secret, hors des zones")
check(Index.ByZone[1][1].Id == "Z1_CanetteDeSoda" and Index.ByZone[1][7].Id == "Z1_PotDeNouilles", "ordre du catalogue, le Pot de nouilles (tuto) compte en zone 1 (13 objets, comme la maquette)")
check(Index.ZoneBonus == 0.05 and Index.Attribute == "IndexDiscovered", "bonus de 5 % par zone (doc 3.4), attribut IndexDiscovered")
local all = {}
for _, item in Items.List do
	all[item.Id] = 1
end
check(Index.CountAll(all) == 83 and #Index.CompletedZones(all) == 6 and near(Index.IncomeBonus(all), 0.3), "tout découvert : 6 zones complètes, +30 %")
all.Secret_ChatPorteBonheurDore = nil
check(#Index.CompletedZones(all) == 6 and Index.CountAll(all) == 82, "sans le Secret : les 6 zones restent complètes (il n'est d'aucune zone)")
all.Z1_PotDeNouilles = nil
check(not Index.IsZoneComplete(all, 1) and Index.IsZoneComplete(all, 2) and near(Index.IncomeBonus(all), 0.25), "sans le Pot de nouilles : zone 1 incomplète, +25 %")
local found, total = Index.CountZone(all, 1)
check(found == 12 and total == 13, `zone 1 : 12 / 13 ({found} / {total})`)
local sf, st = Index.CountSecrets({ Secret_ChatPorteBonheurDore = 5 })
check(sf == 1 and st == 1, "Secrets : 1 / 1")
check(Index.Encode({ Secret_ChatPorteBonheurDore = 1, Z9_Futur = 1, Z1_Donut = 5, Z1_CanetteDeSoda = false }) == "Z1_Donut,Secret_ChatPorteBonheurDore", "Encode : ordre du catalogue, inconnus et faux ignorés")
local set = Index.Decode("Z1_Donut,Z9_Futur,,Secret_ChatPorteBonheurDore")
check(set.Z1_Donut == true and set.Secret_ChatPorteBonheurDore == true and set.Z9_Futur == nil and countKeys(set) == 2, "Decode : ItemId inconnus et vides ignorés")
check(countKeys(Index.Decode(nil)) == 0 and countKeys(Index.Decode(12)) == 0 and countKeys(Index.Decode("")) == 0, "Decode d'un attribut absent, illisible ou vide : rien")
check(not pcall(function()
	Index.ZoneBonus = 1
end), "Config/Index gelé")

section("migration v3 → v4 : les objets déjà possédés sont découverts")
local data = newProfile()
addItem(data, "a", "Z1_CanetteDeSoda", 1, 1, 900) -- exposé (présentoir 1)
addItem(data, "b", "Z3_Smartphone", nil, 3, 700)
data.Vault["1"] = "b" -- au coffre-fort
addItem(data, "c", "Z1_CanetteDeSoda", nil, 1, 600) -- 2e copie, plus ancienne, dans l'inventaire
addItem(data, "d", "Z9_Futur", nil, 9, 500) -- ItemId inconnu du catalogue (gardé tel quel par le jeu)
data.Items.e = { Id = "Z2_YoYo", Source = "PvP", Zone = 2 } -- sans date d'obtention
data.Boxes["1"] = { Tier = "Luxe", Zone = 4, ItemId = "Z4_Couronne", Rarity = "Legendary", ReadyAt = 0 } -- colis sur un établi
local ada = join("Ada", data)
local migratedAt = math.floor(now())
advance(1.5)
local d = dataOf(ada)
check(d ~= nil and d.Version == PROFILE_V, "profil v3 : chargé, passé en v4")
check(d.Index.Z1_CanetteDeSoda == 600, `présentoir et inventaire : date de la plus ancienne copie (600, trouvé {tostring(d.Index.Z1_CanetteDeSoda)})`)
check(d.Index.Z3_Smartphone == 700, "coffre-fort : découvert (700)")
check(d.Index.Z2_YoYo ~= nil and d.Index.Z2_YoYo >= migratedAt - 1 and d.Index.Z2_YoYo <= migratedAt + 1, `sans date d'obtention : la date de la migration ({tostring(d.Index.Z2_YoYo)})`)
check(d.Index.Z9_Futur == nil, "ItemId inconnu du catalogue : pas compté")
check(d.Index.Z4_Couronne == nil, "colis encore sur un établi : pas découvert (son objet reste caché jusqu'à l'ouverture)")
check(countKeys(d.Index) == 3, `3 objets découverts ({countKeys(d.Index)})`)
check(logHas("Ada (Player_1) : migration v4 : Index : 3 objet(s) déjà possédé(s) compté(s) comme découvert(s)", "PRINT", "server"), "une ligne de migration dans la sortie")
check(d.Items.a.Id == "Z1_CanetteDeSoda" and d.Display["1"] == "a" and d.Vault["1"] == "b" and (if PROFILE_V >= 7 then select(2, next(d.Boxes)).ItemId else d.Boxes["2"].ItemId) == "Z4_Couronne" and d.Items.d.Id == "Z9_Futur" and d.Items.e.Source == "PvP", "objets, présentoirs, coffre-fort et colis inchangés")
check(ada:GetAttribute("IndexDiscovered") == "Z1_CanetteDeSoda,Z2_YoYo,Z3_Smartphone", `attribut pour le client, dans l'ordre du catalogue : {tostring(ada:GetAttribute("IndexDiscovered"))}`)
check(logHas("[IndexService] Ada : 3 / 83 objet(s) découvert(s) ; zone(s) complète(s) : aucune", "PRINT", "server"), "IndexService : une ligne au chargement (Studio)")

section("sauvegarde et retour")
leave(ada)
local saved = SAVED["Player_1"]
check(saved ~= nil and saved.Version == PROFILE_V and saved.Index.Z3_Smartphone == 700 and saved.Index.Z1_CanetteDeSoda == 600, "sauvegarde de fin de session : v4 avec son Index")
clearLog()
local back = join("Ada", nil, 1)
advance(0.5)
check(not logHas("migration v", nil, "server"), "déjà en v4 : aucune migration au retour")
check(dataOf(back).Index.Z1_CanetteDeSoda == 600 and back:GetAttribute("IndexDiscovered") == "Z1_CanetteDeSoda,Z2_YoYo,Z3_Smartphone", "même index au retour")

section("vieux profils toujours lisibles")
local v1 = {
	Version = 1,
	Cash = 5,
	Items = {
		u1 = { Id = "Z5_Vase", Source = "NPC", At = 20 }, -- renommé en v2 (Z5_VaseAncien)
		u2 = { Id = "Z6_LiasseDeBillets", Source = "NPC", At = 40 }, -- retiré en v2, remplacé par Z6_LingotDOr
	},
	Display = {},
	Vault = {},
	Boxes = {},
}
local bob = join("Bob", v1)
local bd = dataOf(bob)
check(bd ~= nil and bd.Version == PROFILE_V, "profil v1 : v2, v3 puis v4")
check(bd.Items.u1.Id == "Z5_VaseAncien" and bd.Index.Z5_VaseAncien == 20 and bd.Index.Z5_Vase == nil, "ItemId renommé en v2 : découvert sous son nom v2")
check(bd.Index.Z6_LingotDOr == 40 and bd.Index.Z6_LiasseDeBillets == nil, "ItemId retiré en v2 : son remplaçant est découvert")
check(type(bd.Monetization) == "table" and type(bd.Boosts) == "table" and type(bd.Purchases) == "table", "champs de la v3 complétés")

local cid = join("Cid", { Cash = 1 }) -- sans Version (v0), sans Items
local cd = dataOf(cid)
check(cd ~= nil and cd.Version == PROFILE_V and type(cd.Index) == "table" and next(cd.Index) == nil and type(cd.Items) == "table", "profil sans Version ni Items : chargé en v4, Index vide")
check(cid:GetAttribute("IndexDiscovered") == "", "attribut vide")

local broken = newProfile()
broken.Index = "abîmé"
addItem(broken, "x", "Z1_Donut", nil, 1, 800)
local dan = join("Dan", broken)
check(dataOf(dan) ~= nil and dataOf(dan).Index.Z1_Donut == 800 and countKeys(dataOf(dan).Index) == 1, "Index qui n'est pas une table : repart vide, puis l'objet possédé y entre")
check(logHas("Dan (Player_4) : migration v4 : Index n'est pas une table (abîmé) : repart vide", "WARN", "server"), "avertissement dans la sortie")

local eve = join("Eve", nil) -- nouveau joueur : le modèle
check(dataOf(eve) ~= nil and dataOf(eve).Version == PROFILE_V and type(dataOf(eve).Index) == "table" and next(dataOf(eve).Index) == nil, "nouveau profil : créé en v4, Index vide")
check(not logHas("Eve (Player_5) : migration", nil, "server"), "nouveau profil : aucune migration")

local future = newProfile(4)
future.Version = PROFILE_V + 1 -- copie a48 : la v6 est prise par les gains hors ligne (a46 : la v5 par les colis)
local kicks = #KICKS
local fay = join("Fay", future)
check(#KICKS == kicks + 1 and KICKS[#KICKS].player == fay and dataOf(fay) == nil, "profil v5 (écrit par une version plus récente) : pas chargé, joueur expulsé")
check(SAVED["Player_6"] == nil or SAVED["Player_6"].Version == PROFILE_V + 1, `profil v{PROFILE_V + 1} laissé tel quel`)

section("filet d'IndexService au chargement")
leave(eve)
leave(cid)
local v4 = newProfile(4)
v4.Index = { Z1_Banane = 300 }
addItem(v4, "g1", "Z1_Banane", 1, 1, 300)
addItem(v4, "g2", "Z2_Sucette", 2, 2, 450) -- possédé, absent de l'Index (entré par un chemin sans Discover)
addItem(v4, "g3", "Z9_Futur", nil, 9, 460) -- inconnu : jamais compté
clearLog()
local gus = join("Gus", v4)
advance(0.5)
local gd = dataOf(gus)
check(gd ~= nil and gd.Version == PROFILE_V and not logHas("Gus (Player_7) : migration", nil, "server"), "profil v4 : aucune migration")
check(gd.Index.Z2_Sucette == 450 and gd.Index.Z1_Banane == 300 and gd.Index.Z9_Futur == nil, "objet possédé absent de l'Index : ajouté à sa date d'obtention ; l'inconnu non")
check(logHas("[IndexService] Gus : 2 / 83 objet(s) découvert(s), dont 1 objet(s) possédé(s) ajouté(s) au chargement", "PRINT", "server"), "une ligne dans la sortie (Studio)")
check(gus:GetAttribute("IndexDiscovered") == "Z1_Banane,Z2_Sucette", `attribut : {tostring(gus:GetAttribute("IndexDiscovered"))}`)
check(#notifies(gus) == 0, "aucun message au chargement")

summary("scénario migration")

--!nocheck
-- Banc a141 (2026-11-14, L-141 : boutique de 48 studs, présentoirs déplacés), scénario « restore » sur la mise en
-- place du banc a105 : au retour du joueur, un objet posé au sol avec l'ancienne forme revient dans l'inventaire
-- s'il ne tient plus entier dans Bounds ou s'il est à moins de StandClearance d'un présentoir ; les autres
-- restent au sol, UnlockAt gardé.

advance(1000)
startServer()

local Unbox = sharedModule("Config/Unbox")

local ada = join("Ada", nil)
advance(1.5)
local plot = shopOf(ada)

section("trois objets posés avec l'ancienne forme (64 studs)")
local keep = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
local eKeep = placeItemAt(ada, keep, -20, 16)
local stand = bringItem(ada, "Z3_Smartphone", "Rare", 3)
local eStand = placeItemAt(ada, stand, 6, 10)
local wall = bringItem(ada, "Z3_Smartphone", "Rare", 3)
local eWall = placeItemAt(ada, wall, 28, 16)
check(eKeep.Spot ~= nil and eStand.Spot ~= nil and eWall.Spot ~= nil, "trois objets posés")
local unlockKeep, unlockStand = eKeep.UnlockAt, eStand.UnlockAt

leave(ada)
advance(1)

section("Clément refait la boutique : 48 studs, un présentoir sous un objet")
local bounds = plot:FindFirstChild("Bounds")
bounds.Size = Vector3.new(48, bounds.Size.Y, bounds.Size.Z)
local slot = plot:FindFirstChild("DisplaySlot_20", true)
slot.CFrame = CFrame.new(6 + Unbox.StandClearance - 0.5, 3.8 - 0.15, 10)

local ada2 = join("Ada", nil, ada.UserId)
advance(1.5)
local items = dataOf(ada2).Items
check(items[keep].Spot ~= nil and floorItemOf(ada2, keep) ~= nil and near(items[keep].UnlockAt, unlockKeep), "objet loin des présentoirs, dans Bounds : remis au sol")
check(items[stand].Spot == nil and floorItemOf(ada2, stand) == nil and near(items[stand].UnlockAt, unlockStand), "objet sur un présentoir : dans l'inventaire, UnlockAt gardé")
check(items[stand].AntiTheft == true and items[wall].AntiTheft == true, "toujours sous antivol")
check(items[wall].Spot == nil and floorItemOf(ada2, wall) == nil, "objet hors de la nouvelle largeur : dans l'inventaire")
check(logHas("sur un présentoir", "WARN") and logHas("hors du volume Bounds", "WARN"), "une ligne dans la sortie pour chacun")

section("pose refusée à côté d'un présentoir (même règle qu'avant)")
local again = bringItem(ada2, "Z3_Smartphone", "Rare", 3)
local before = #notifies(ada2)
local e = placeItemAt(ada2, again, 6, 10)
check(e.Spot == nil and #notifies(ada2) == before + 1, "PlaceBox à côté du présentoir : refusé, un message")

summary("scénario restore")

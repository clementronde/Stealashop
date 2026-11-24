--!nocheck
-- Scénario « lock » du banc a178 (vague 55, points 3 et 4) : BB_AntiTheft d'un objet au sol se montre selon la
-- distance au PERSONNAGE (Unbox.LockShowDistance), MaxDistance du billboard levée ; un objet tenu en main encore
-- sous antivol porte BB_AntiTheft (LOCKED ou minuteur), un objet libre tenu n'en a pas.
advance(1000)
startServer()
local ada = join("Ada", nil)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Unbox = clientModule("UnboxController")
local UnboxConfig = sharedModule("Config/Unbox")

section("objet au sol : distance au personnage")
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
local entry = placeItemAt(ada, uid, 6, 0)
check(entry and entry.Spot ~= nil, "objet posé au sol, antivol en cours")
local model = floorItemOf(ada, uid)
local gui = model and model:FindFirstChild("BB_AntiTheft", true)
check(gui ~= nil and gui.MaxDistance == math.huge, `MaxDistance levée ({gui and gui.MaxDistance})`)
check(UnboxConfig.LockShowDistance == 40, "LockShowDistance V0 = 40")
local base = model:GetPivot().Position
moveTo(ada, base + Vector3.new(30, 3, 0))
advance(0.3)
check(gui.Enabled == true, "à 30 studs du personnage : verrou montré")
moveTo(ada, base + Vector3.new(60, 3, 0))
advance(0.3)
check(gui.Enabled == false, "à 60 studs du personnage : verrou caché")
moveTo(ada, base + Vector3.new(10, 3, 0))
advance(0.3)
check(gui.Enabled == true, "revenu à 10 studs : montré de nouveau")

section("objet tenu en main sous antivol")
local uid2 = bringItem(ada, "Z3_Smartphone", "Rare", 3)
local item2 = dataOf(ada).Items[uid2]
check(item2 and item2.AntiTheft == true and item2.Spot == nil, "objet sous antivol dans l'inventaire")
advance(0.3)
holdAs(ada, uid2)
advance(0.3)
local tool = heldTool(ada)
local held = tool and tool:FindFirstChild("HeldItem")
check(held and held:GetAttribute("AntiTheft") == true, "modèle tenu : attribut AntiTheft")
local view = held and Unbox.GetHeldView(held)
local expected = if type(item2.UnlockAt) == "number" then nil else UnboxConfig.LockedText
check(view ~= nil and view.Shown == true, "BB_AntiTheft sur l'objet en main, montré")
check(view and (expected == nil or view.TimeText == expected), `texte du verrou ({view and view.TimeText})`)
check(held and held:FindFirstChild("BB_AntiTheft", true) ~= nil, "billboard posé dans l'objet tenu")
holdAs(ada, uid2) -- même uid : rien ne change
advance(0.3)

section("objet libre tenu : pas de verrou")
local unlockedModel = floorItemOf(ada, uid)
advance(antiTheftOf("Epic") + 1)
standNear(ada, unlockedModel:GetPivot().Position)
advance(0.3)
fireAs(ada, "OpenBox", uid)
flush()
advance(0.5)
local tool3 = heldTool(ada)
local held3 = tool3 and tool3:FindFirstChild("HeldItem")
if tool3 == nil or tool3:GetAttribute("HeldItemUid") ~= uid then
	holdAs(ada, uid)
	advance(0.3)
	tool3 = heldTool(ada)
	held3 = tool3 and tool3:FindFirstChild("HeldItem")
end
check(tool3 and tool3:GetAttribute("HeldItemUid") == uid, "objet débloqué en main")
check(held3 and held3:GetAttribute("AntiTheft") == nil and Unbox.GetHeldView(held3) == nil, "pas de verrou sur un objet libre")
check(held == nil or Unbox.GetHeldView(held) == nil, "verrou de l'objet rangé retiré")

summary("scénario lock")

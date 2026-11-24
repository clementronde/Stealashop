--!nocheck
-- Banc pc-l140 (2026-11-14, Cantin, L-140) : StoreClimbController coupe la grimpe (état Climbing) du perso
-- local dans le volume Bounds d'un magasin PNJ, la rend dehors et à la réapparition.
-- Magasins : Supérette (Bounds -28,5..28,5 × 0,45..14,85 × -34,5..34,5, comme en jeu), un magasin tourné de
-- 45°, un magasin dans _INBOX_CLEMENT (ignoré) et un magasin sans Bounds (pas d'erreur).

local ShelfCaps = REQUIRE(game.ReplicatedStorage.Shared.Config.ShelfCaps)
local Controller = CLIENT_REQUIRE("client/Controllers/StoreClimbController.luau")

local function boundsStore(name, frame, parent)
	local m = NEW("Model", name)
	local b = NEW("Part", "Bounds")
	b.Size = Vector3.new(57, 14.4, 69)
	b.CFrame = frame * CFrame.new(0, 7.65, 0)
	b.CanCollide = false
	b.Transparency = 1
	local inner = NEW("Folder", "Interior"); inner.Parent = m
	b.Parent = inner -- cherché en profondeur, comme dans les modèles de Clément
	m.Parent = parent
	CS:AddTag(m, "NPCStore")
	return m
end

local fA = CFrame.new(0, 0, 0)
boundsStore("STORE_Z1_Superette", fA, WORKSPACE)
local fB = CFrame.new(400, 0, 0) * CFrame.AnglesY(math.rad(45))
boundsStore("STORE_Z2_Londres", fB, WORKSPACE)
local inbox = NEW("Folder", "_INBOX_CLEMENT"); inbox.Parent = WORKSPACE
boundsStore("STORE_Z3_Livraison", CFrame.new(-400, 0, 0), inbox)
local nob = NEW("Model", "STORE_Z4_SansBounds"); nob.Parent = WORKSPACE
CS:AddTag(nob, "NPCStore")

local OUTSIDE = Vector3.new(0, 3, -60) -- devant la vitrine
local INSIDE = Vector3.new(-12, 3, 0) -- allée de gauche
local function climbOn(h) return h:GetStateEnabled("Climbing") end

section("C1 dehors")
local c1, h1, r1 = SPAWN(OUTSIDE)
START_CONTROLLER(Controller)
TICK()
check(climbOn(h1) and not Controller.IsClimbBlocked(), "C1 dehors : grimpe normale")
check(#h1.Changes == 0, "C1 dehors : on ne touche pas au Humanoid")

section("C2 dans le magasin")
r1.CFrame = CFrame.new(INSIDE)
TICK()
check(not climbOn(h1) and Controller.IsClimbBlocked(), "C2 dans Bounds : grimpe coupée")
TICK()
check(#h1.Changes == 1, "C2 une seule coupure, pas à chaque tour")
check(h1.Current == "Running", "C2 pas grimpant : état inchangé")

section("C3 dehors à nouveau")
r1.CFrame = CFrame.new(OUTSIDE)
TICK()
check(climbOn(h1) and not Controller.IsClimbBlocked(), "C3 sorti : grimpe rendue")

section("C4 grimpe en cours à l'entrée")
h1.Current = "Climbing"
r1.CFrame = CFrame.new(-12, 9.3, 0) -- accroché à la face d'une gondole, hanches à 9,3
TICK()
check(not climbOn(h1) and h1.Current == "Freefall", "C4 grimpe coupée et perso décroché (Freefall)")

section("C5 réapparition")
-- mort dans le magasin : le nouveau perso apparaît dehors (parcelle)
c1.Parent = nil
local c2, h2, r2 = SPAWN(OUTSIDE)
TICK()
check(climbOn(h2) and not Controller.IsClimbBlocked(), "C5 nouveau perso dehors : grimpe normale")
check(#h2.Changes == 0, "C5 nouveau perso : aucune coupure héritée")
r2.CFrame = CFrame.new(INSIDE)
TICK()
check(not climbOn(h2), "C5 nouveau perso dans le magasin : grimpe coupée")
-- réapparition pendant la coupure, ancien perso encore là : il retrouve la grimpe
local c3, h3, r3 = SPAWN(OUTSIDE)
TICK()
check(climbOn(h2), "C5 ancien perso encore présent : grimpe rendue")
check(climbOn(h3) and not Controller.IsClimbBlocked(), "C5 perso réapparu dehors : grimpe normale")
-- réapparition dans le magasin (cas d'école) : coupée tout de suite (task.defer de CharacterAdded)
local c4, h4 = SPAWN(INSIDE)
TICK()
check(not climbOn(h4), "C5 perso réapparu dans Bounds : grimpe coupée")

section("C6 magasin tourné, inbox, sans Bounds")
local c5, h5, r5 = SPAWN(OUTSIDE)
TICK()
-- (27, 3, 30) dans le repère du magasin tourné : dedans ; (31, 3, 30) : juste dehors.
r5.CFrame = CFrame.new(fB * Vector3.new(27, 3, 30))
TICK()
check(not climbOn(h5), "C6 magasin tourné de 45° : coupée dans Bounds")
r5.CFrame = CFrame.new(fB * Vector3.new(31, 3, 30))
TICK()
check(climbOn(h5), "C6 magasin tourné : rendue juste hors de Bounds")
r5.CFrame = CFrame.new(-400, 3, 0)
TICK()
check(climbOn(h5), "C6 magasin dans _INBOX_CLEMENT : ignoré")
check(ShelfCaps.NoClimbInStores == true and ShelfCaps.ClimbCheckInterval > 0, "C6 valeurs V0 (NoClimbInStores, ClimbCheckInterval)")

section("C7 sans perso")
LOCAL_PLAYER.Character = nil
TICK()
check(true, "C7 sans perso : pas d'erreur")
local warns = 0
for _, l in LOG do if l.kind == "WARN" then warns += 1 end end
check(warns == 0, `C7 aucun avertissement ({warns})`)

summary("scénario grimpe")

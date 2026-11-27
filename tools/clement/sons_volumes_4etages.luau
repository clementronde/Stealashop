-- Volumes en 4 étages (repasse qualité du 26/11, chef VFX et son ; skill sound-design, section 3)
-- À coller dans la barre de commande de Studio, en Edit. NE PAS APPLIQUER avant que Clément puisse écouter
-- (Chef de projet, 26/11) : avec APPLY = false, le script n'affiche que le tableau avant → après.
--   petits ≈ 0,2 à 0,3 · moyens ≈ 0,5 · grands 1 à 1,5 · très grands 1,5 à 2
-- Seul le Volume des Sound change : ni SoundId, ni nom, ni code. Les sons absents de la liste ne bougent pas.
-- Retour en arrière : la colonne « avant » de la sortie (et le paquet repasse-vfx-son) donne l'ancienne valeur.

local APPLY = false

local VOLUMES: { [string]: number } = {
	-- petits (répétés, navigation)
	UI_Hover = 0.2, UI_SliderTick = 0.3, Unbox_OddsTick = 0.3, Train_Gain = 0.3, Bubble_Pop = 0.3,
	UI_Click_Classic = 0.3, UI_Click_Sharp = 0.3, UI_Click_Tick = 0.3, UI_Click_Bubble = 0.3, UI_Click_Soft = 0.3,
	Unbox_InspectHmm = 0.3, Unbox_Rummage = 0.3, Unbox_BoxSlide = 0.3, Unbox_Toss = 0.3, CameraRadar_Beep = 0.3,
	Heist_Breath = 0.3, Shop_BuildClick = 0.3,
	-- moyens (sélection, gestes)
	UI_Click = 0.5, UI_Open = 0.4, UI_Close = 0.4, UI_Whoosh = 0.4, UI_Success = 0.5, UI_Equip = 0.5, UI_Deny = 0.5,
	Place_Release = 0.5, Cash_Pad = 0.5, Unbox_TierNote = 0.5, Unbox_Rattle = 0.5, Unbox_Swing = 0.5,
	Unbox_Kick = 0.6, Unbox_KickWhoosh = 0.5, Unbox_Windup = 0.5, Unbox_InspectDing = 0.5, Unbox_InspectScan = 0.4,
	Unbox_JunkBoing = 0.5, Unbox_JunkSqueak = 0.5, Unbox_Silhouette = 0.5, Unbox_Tier = 0.6, Unbox_Smoke = 0.5,
	Potion_Pick = 0.5, Potion_Drink = 0.5, Witness_Photo = 0.4, Witness_Call = 0.5, Guard_Radio = 0.5,
	Crowd_Cheer = 0.4, Crowd_Boo = 0.4, Crowd_Shout = 0.4, Crowd_Scream = 0.4, Crowd_Gasp = 0.4, Crowd_Clap = 0.4,
	Crowd_PhotoBurst = 0.4, Glass_Hit = 0.6, Chase_Whistle = 0.6, Shop_Buy = 0.6, Unlock = 0.6, BenchLift_Top = 0.5,
	-- grands (encaissement, prise, casse, fuite)
	Cash_Collect = 1, Offline_Claim = 1, Heist_Grab = 1, Grab_Grab = 1, Unbox_Burst = 1.2, Unbox_UpgradePop = 1,
	Unbox_Confetti = 1, Heist_Escape = 1.2, Glass_BreakShatter = 1, Glass_BreakThud = 1.2, Throw_GlassBurst = 1.2,
	HitWindow_Impact = 0.8, HitWindowHeavy_Impact = 1, SwingBat_Impact = 1, SwingBat_Hit = 1, Catch_Impact = 1,
	Catch_Slam = 1, Knockdown_Land = 1, Arrested_Grab = 1, Throw_Hit = 1, Shelf_Break = 1, Ceiling_Crash = 1.2,
	Reveal_RarityLow = 1, Reveal_RarityMid = 1.2, Reveal_Land = 1, Reveal_GrowSmall = 0.8, Reveal_GrowLarge = 1,
	SFX_ChaseStart = 1, SFX_TruckHit = 1, Night_WallRise = 1, Index_Reward = 1, Unbox_HammerHit = 1,
	Unbox_CrowbarCrack = 1,
	-- très grands (les moments rares)
	Heist_SafeFlash = 1.6, Reveal_RarityHigh = 1.6, Reveal_GrowColossal = 1.5, Reveal_LandColossal = 1.8,
	Rebirth = 1.6, SFX_TruckExplosion = 1.5,
}
-- Musiques d'ambiance : au niveau des musiques de zone
local MUSIC: { [string]: number } = {
	MUS_Ambient_MorningMood = 0.4, MUS_Ambient_Spring = 0.4, MUS_Ambient_TurkishMarch = 0.4,
	MUS_Ambient_Gymnopedie = 0.4, MUS_Ambient_ClairDeLune = 0.4,
}

local A = game.ReplicatedStorage.Assets
local rows, missing, seen = {}, {}, {}
local function apply(root: Instance?, list: { [string]: number })
	if not root then return end
	for _, s in root:GetDescendants() do
		if s:IsA("Sound") then
			local v = list[s.Name]
			if v then
				seen[s.Name] = true
				table.insert(rows, string.format("%s : %.2f → %.2f", s:GetFullName():gsub("ReplicatedStorage%.Assets%.", ""), s.Volume, v))
				if APPLY then s.Volume = v end
			end
		end
	end
end
apply(A:FindFirstChild("Sounds"), VOLUMES)
apply(A:FindFirstChild("Music"), MUSIC)
for name in VOLUMES do
	if not seen[name] then table.insert(missing, name) end
end
table.sort(rows)
local head = if APPLY then "[volumes] APPLIQUÉ" else "[volumes] aperçu seulement (APPLY = false)"
print(head .. " : " .. #rows .. " sons ; absents : " .. (if #missing > 0 then table.concat(missing, ", ") else "aucun"))
return head .. "\n" .. table.concat(rows, "\n") .. (if #missing > 0 then "\nabsents : " .. table.concat(missing, ", ") else "")

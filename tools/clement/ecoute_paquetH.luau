-- Paquet H, sons : pose les candidats numérotés à écouter dans Workspace/_ECOUTE_PaquetH (aucun script).
-- Écoute : Play solo (F5), Explorateur > Workspace > _ECOUTE_PaquetH > un Sound > Propriétés > cocher Playing.
-- Sons sous licence Roblox (compte Roblox), ProSoundEffects ou APM (APMOfficial). Mesurés le 26/11 (AudioAnalyzer, en Edit).
-- À supprimer après les choix de Clément.

local CANDIDATS = {
	-- Départ de la poursuite (Heist_Grab, même nom) : coup court avec de la basse
	{ "Grab_0_Actuel", 9039709283, "son actuel, pour comparer" },
	{ "Grab_1", 9120728815, "Whoosh Heavy Punches 1 : coup court, 0,25 s, 68 % de graves" },
	{ "Grab_2", 9119858707, "Synth Whomps 20 : boum synthé, 0,45 s, 72 % de graves" },
	{ "Grab_3", 9114079718, "Dinosaur Boomy Thumps 2 : gros coup sourd, 1 s, 89 % de graves" },
	-- Ligne safe (Heist_SafeFlash ou Heist_Escape) : un kaching familier, plus fort
	{ "Kaching_1", 111773238101465, "le kaching des plaques (Cash_Pad), familier" },
	{ "Kaching_2", 9113728756, "Cash Register 5 : caisse enregistreuse, 0,7 s" },
	{ "Kaching_3", 9113728625, "Cash Register 1 : ding très court" },
	-- Tic du tapis (Training/Train_Tick) : grave et doux, volume bas
	{ "Tick_1", 16480568148, "Roblox Pinball Soft Click 05" },
	{ "Tick_2", 16480568821, "Roblox Pinball Soft Click 01" },
	{ "Tick_3", 16480568432, "Roblox Pinball Soft Click 03" },
	-- Tap du joueur sur le colis (Unbox/Unbox_Tap) : court et doux
	{ "Tap_1", 16480568611, "Roblox Pinball Soft Click 02 (le plus grave)" },
	{ "Tap_2", 16480567946, "Roblox Pinball Weighted Click 01" },
	{ "Tap_3", 16480560696, "Roblox Pinball Giant Button Press 02" },
	-- « SUPER LUCK! » (Unbox/Unbox_SuperLuck) : un grand moment
	{ "SuperLuck_1", 1846251193, "Jackpot Mania « Win » (APM) : petit jingle de jackpot" },
	{ "SuperLuck_2", 16480575523, "Roblox Pinball Big Metal Tally 04 : comptage métallique" },
	{ "SuperLuck_3", 16480570385, "Roblox Pinball Bumper Low Bells 05 : cloches graves" },
	-- Pose sur un présentoir (Display/Display_Place) : court
	{ "Place_1", 15675055424, "Roblox UI Cute Pop : petit pop doux" },
	{ "Place_2", 9119605384, "Statue Put Down 1 : pose lourde, très grave" },
	{ "Place_3", 16480556621, "Roblox Pinball Large Plastic Button : clic net" },
}

local old = workspace:FindFirstChild("_ECOUTE_PaquetH")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "_ECOUTE_PaquetH"
for _, c in CANDIDATS do
	local s = Instance.new("Sound")
	s.Name = c[1]
	s.SoundId = "rbxassetid://" .. c[2]
	s.Volume = 1
	s:SetAttribute("Candidat", c[3])
	s.Parent = folder
end
folder.Parent = workspace
game:GetService("ContentProvider"):PreloadAsync(folder:GetChildren())
for _, s in folder:GetChildren() do
	local snd = s :: Sound
	print(snd.Name, snd.IsLoaded, ("%.2f s"):format(snd.TimeLength), snd:GetAttribute("Candidat"))
end

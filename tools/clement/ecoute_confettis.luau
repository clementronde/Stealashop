-- Écoute des sons de confettis des feux d'artifice (L-371), en Edit, sans Play.
-- Mets le numéro du candidat sur la ligne N ci-dessous, colle tout dans la barre de commande de Studio, Entrée.
-- Le son se joue une fois puis tout est retiré : rien ne reste dans la place.
--
--   1. Roblox_UI_Cute_Pop (Roblox)            : petit pop rond et doux, le plus « Roblox », 0,3 s, grave (≈ 1,2 kHz)
--   2. Balloon Pop 3 (ProSoundEffects)        : pop de ballon net et fort, 0,15 s (≈ 2,2 kHz)
--   3. Pop Paper Bag Pop 1 (ProSoundEffects)  : sac en papier qu'on gonfle puis qui éclate, 0,7 s, plus aigu (≈ 4,3 kHz)
--
-- Sons sous licence Roblox (compte Roblox) ou de son partenaire ProSoundEffects ; pas de son mis en ligne par un joueur.

local N = 1

local CANDIDATS = { 15675055424, 9113263649, 9117844225 }
local id = CANDIDATS[N]
assert(id, "N doit valoir 1, 2 ou 3")

local folder = Instance.new("Folder")
folder.Name = "_ECOUTE_Confettis"
folder.Parent = game:GetService("SoundService")
local player = Instance.new("AudioPlayer")
player.Asset = "rbxassetid://" .. id
player.Parent = folder
local output = Instance.new("AudioDeviceOutput")
output.Parent = folder
local wire = Instance.new("Wire")
wire.SourceInstance = player
wire.TargetInstance = output
wire.Parent = folder

local t0 = os.clock()
while not player.IsReady and os.clock() - t0 < 5 do
	task.wait(0.05)
end
print(("Candidat %d : rbxassetid://%d"):format(N, id))
player:Play()
task.wait(math.max(player.TimeLength, 0.5) + 0.3)
folder:Destroy()

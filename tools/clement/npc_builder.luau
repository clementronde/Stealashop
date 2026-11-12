--!strict
-- Constructeur des témoins PNJ et du policier (liaison L-111), pour Clément. Mode Edit, relançable.
--
-- Même rig que les vigiles (R15 standard, Humanoid + Animator, DisplayDistanceType None, aucun script),
-- habillés en pièces simples (accessoires ACC_*).
--  - NPC_Witness_Z<n>_01 et _02 dans Workspace/Map/Zone_<n>/Witnesses : sur le trottoir d'en face d'un des
--    deux magasins de la zone (_01 regarde celui du sud, _02 celui du nord), à 1,8 stud de la bordure et à
--    10 studs de l'axe de la vitrine, tournés vers elle (attribut WatchedStore). HumanoidRootPart ancré.
--    Attachment WitnessHead dans la tête. Téléphone ACC_Temoin_Telephone dans la main droite. Dossier
--    Animations (Idle, Look, CallPolice) gardé si le modèle existe déjà.
--  - NPC_Police dans ReplicatedStorage/Assets/Guards, animations des vigiles copiées (Idle, Walk, Run, Catch,
--    Tired) si son dossier Animations n'existe pas encore.
--  - Rig_Witness dans ServerStorage/AnimRigs : rig de travail de l'éditeur d'animation (look du premier témoin).
--
-- Données générées depuis StealAShop-Art/Guards/_scripts/npc_data.py (make_npc_luau.py).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DATA = HttpService:JSONDecode([==[{"witnesses":[{"name":"NPC_Witness_Z1_01","zone":1,"scale":1.0,"task":"L-111","body":{"Head":"F1D1B5","UpperTorso":"9C6FB0","LowerTorso":"6B6F7A","RightUpperArm":"9C6FB0","LeftUpperArm":"9C6FB0","RightLowerArm":"9C6FB0","LeftLowerArm":"9C6FB0","RightHand":"F1D1B5","LeftHand":"F1D1B5","RightUpperLeg":"6B6F7A","LeftUpperLeg":"6B6F7A","RightLowerLeg":"CDB79E","LeftLowerLeg":"CDB79E","RightFoot":"4A3A30","LeftFoot":"4A3A30"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z1_Chignon","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"DADBE0","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"DADBE0","name":"Back"},{"shape":"Block","size":[1.22,0.2,0.1],"pos":[0,0.41,-0.57],"rot":[0,0,0],"color":"DADBE0","name":"Fringe"},{"shape":"Ball","size":[0.55,0.55,0.55],"pos":[0,0.8,0.36],"rot":[0,0,0],"color":"DADBE0","name":"Bun"}]},{"name":"ACC_Z1_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.04,0.035,0.035],"pos":[0,0.25,-0.61],"rot":[0,0,0],"color":"9A7A3A","name":"Bar"},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[-0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensL","transparency":0.55},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensR","transparency":0.55},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"9A7A3A","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"9A7A3A","name":"TempleR"}]},{"name":"ACC_Z1_Cabas","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.95,0.85,0.5],"pos":[0,-0.85,0],"rot":[0,0,0],"color":"C8452E","name":"Bag"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[-0.25,-0.3,0],"rot":[0,0,0],"color":"7A2A1C","name":"HandleL"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[0.25,-0.3,0],"rot":[0,0,0],"color":"7A2A1C","name":"HandleR"},{"shape":"Block","size":[0.14,0.7,0.14],"pos":[0.22,-0.4,0.08],"rot":[0,0,-10],"color":"6DBB45","name":"Leek"},{"shape":"Block","size":[0.16,0.22,0.16],"pos":[0.27,-0.84,0.08],"rot":[0,0,-10],"color":"F2F2EA","name":"LeekWhite"}]}],"witness":true},{"name":"NPC_Witness_Z1_02","zone":1,"scale":1.0,"task":"L-111","body":{"Head":"C68E62","UpperTorso":"E8562E","LowerTorso":"2F4A7A","RightUpperArm":"E8562E","LeftUpperArm":"E8562E","RightLowerArm":"E8562E","LeftLowerArm":"E8562E","RightHand":"C68E62","LeftHand":"C68E62","RightUpperLeg":"2F4A7A","LeftUpperLeg":"2F4A7A","RightLowerLeg":"2F4A7A","LeftLowerLeg":"2F4A7A","RightFoot":"F2F2F2","LeftFoot":"F2F2F2"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z1_CasquetteEnvers","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.42,1.24,1.24],"pos":[0,0.5,0],"rot":[0,0,90],"color":"1E7BD8","name":"Crown"},{"shape":"Block","size":[0.98,0.07,0.56],"pos":[0,0.31,0.83],"rot":[10,0,0],"color":"1B5FA8","name":"Visor"},{"shape":"Cylinder","size":[0.06,0.16,0.16],"pos":[0,0.74,0],"rot":[0,0,90],"color":"1E7BD8","name":"Button"}]},{"name":"ACC_Z1_Capuche","attach":"BodyBackAttachment","type":"Back","parts":[{"shape":"Block","size":[1.3,0.55,0.35],"pos":[0,0.62,0.62],"rot":[0,0,0],"color":"D44A26","name":"Hood"},{"shape":"Block","size":[1.1,0.42,0.04],"pos":[0,-0.52,-0.52],"rot":[0,0,0],"color":"D44A26","name":"Pocket"},{"shape":"Block","size":[0.05,0.4,0.04],"pos":[-0.18,0.42,-0.525],"rot":[0,0,0],"color":"F2F2F2","name":"StringL"},{"shape":"Block","size":[0.05,0.4,0.04],"pos":[0.18,0.42,-0.525],"rot":[0,0,0],"color":"F2F2F2","name":"StringR"}]}],"witness":true},{"name":"NPC_Witness_Z2_01","zone":2,"scale":1.0,"task":"L-111","body":{"Head":"F2D0B4","UpperTorso":"3D4048","LowerTorso":"3D4048","RightUpperArm":"3D4048","LeftUpperArm":"3D4048","RightLowerArm":"3D4048","LeftLowerArm":"3D4048","RightHand":"F2D0B4","LeftHand":"F2D0B4","RightUpperLeg":"3D4048","LeftUpperLeg":"3D4048","RightLowerLeg":"3D4048","LeftLowerLeg":"3D4048","RightFoot":"141416","LeftFoot":"141416"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z2_ChapeauMelon","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Ball","size":[1.18,1.18,1.18],"pos":[0,0.62,0],"rot":[0,0,0],"color":"1B1B1E","name":"Crown"},{"shape":"Cylinder","size":[0.06,1.55,1.55],"pos":[0,0.45,0],"rot":[0,0,90],"color":"1B1B1E","name":"Brim"},{"shape":"Cylinder","size":[0.12,1.2,1.2],"pos":[0,0.54,0],"rot":[0,0,90],"color":"5A2A2A","name":"Band"}]},{"name":"ACC_Z2_Moustache","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[0.46,0.1,0.06],"pos":[0,-0.1,-0.6],"rot":[0,0,0],"color":"6B5B4E","name":"Center"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[-0.3,-0.06,-0.6],"rot":[0,0,-25],"color":"6B5B4E","name":"CurlL"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[0.3,-0.06,-0.6],"rot":[0,0,25],"color":"6B5B4E","name":"CurlR"}]},{"name":"ACC_Z2_Chemise","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.46,0.6,0.04],"pos":[0,0.53,-0.515],"rot":[0,0,0],"color":"F7F7F7","name":"Shirt"},{"shape":"Block","size":[0.16,0.9,0.04],"pos":[0,0.32,-0.53],"rot":[0,0,0],"color":"8E1B26","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"8E1B26","name":"Knot"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[-0.25,0.47,-0.525],"rot":[0,0,-18],"color":"2E3138","name":"LapelL"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[0.25,0.47,-0.525],"rot":[0,0,18],"color":"2E3138","name":"LapelR"},{"shape":"Block","size":[0.22,0.1,0.04],"pos":[-0.55,0.32,-0.525],"rot":[0,0,0],"color":"F7F7F7","name":"PocketSquare"}]},{"name":"ACC_Z2_Parapluie","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[1.4,0.24,0.24],"pos":[0,-0.85,0],"rot":[0,0,90],"color":"141416","name":"Canopy"},{"shape":"Block","size":[0.08,0.3,0.08],"pos":[0,-0.05,0],"rot":[0,0,0],"color":"5A3A24","name":"Crook"},{"shape":"Cylinder","size":[0.22,0.06,0.06],"pos":[0,-1.66,0],"rot":[0,0,90],"color":"B0B0B0","name":"Tip"}]}],"witness":true},{"name":"NPC_Witness_Z2_02","zone":2,"scale":1.0,"task":"L-111","body":{"Head":"E8BFA0","UpperTorso":"C9A877","LowerTorso":"C9A877","RightUpperArm":"C9A877","LeftUpperArm":"C9A877","RightLowerArm":"C9A877","LeftLowerArm":"C9A877","RightHand":"E8BFA0","LeftHand":"E8BFA0","RightUpperLeg":"2E2E36","LeftUpperLeg":"2E2E36","RightLowerLeg":"2E2E36","LeftLowerLeg":"2E2E36","RightFoot":"5A3A24","LeftFoot":"5A3A24"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z2_Gavroche","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.22,1.3,1.3],"pos":[0,0.62,0.05],"rot":[0,0,90],"color":"6E6A60","name":"Crown"},{"shape":"Block","size":[1.0,0.06,0.4],"pos":[0,0.55,-0.7],"rot":[-8,0,0],"color":"5E5A52","name":"Visor"}]},{"name":"ACC_Z2_Echarpe","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[1.3,0.28,1.12],"pos":[0,0.8,0],"rot":[0,0,0],"color":"B3262E","name":"Wrap"},{"shape":"Block","size":[0.3,0.75,0.06],"pos":[0.35,0.35,-0.54],"rot":[0,0,0],"color":"B3262E","name":"End"},{"shape":"Block","size":[0.31,0.06,0.07],"pos":[0.35,0.45,-0.54],"rot":[0,0,0],"color":"1E3A5F","name":"Check"},{"shape":"Block","size":[0.31,0.06,0.07],"pos":[0.35,0.2,-0.54],"rot":[0,0,0],"color":"1E3A5F","name":"Check"},{"shape":"Block","size":[0.06,0.76,0.07],"pos":[0.35,0.35,-0.545],"rot":[0,0,0],"color":"E8C547","name":"Check"}]},{"name":"ACC_Z2_Ceinture","attach":"WaistCenterAttachment","type":"Waist","parts":[{"shape":"Block","size":[2.02,0.14,1.06],"pos":[0,0.12,0],"rot":[0,0,0],"color":"A88A5E","name":"Belt"},{"shape":"Block","size":[0.26,0.18,0.05],"pos":[0,0.12,-0.545],"rot":[0,0,0],"color":"6E5636","name":"Buckle"}]}],"witness":true},{"name":"NPC_Witness_Z3_01","zone":3,"scale":1.0,"task":"L-111","body":{"Head":"EBC9A6","UpperTorso":"1E2433","LowerTorso":"1E2433","RightUpperArm":"1E2433","LeftUpperArm":"1E2433","RightLowerArm":"1E2433","LeftLowerArm":"1E2433","RightHand":"EBC9A6","LeftHand":"EBC9A6","RightUpperLeg":"1E2433","LeftUpperLeg":"1E2433","RightLowerLeg":"1E2433","LeftLowerLeg":"1E2433","RightFoot":"2B2B2E","LeftFoot":"2B2B2E"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z3_Cheveux","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"141416","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"141416","name":"Back"},{"shape":"Block","size":[1.22,0.2,0.1],"pos":[0,0.41,-0.57],"rot":[0,0,0],"color":"141416","name":"Fringe"}]},{"name":"ACC_Z3_Cartable","attach":"BodyBackAttachment","type":"Back","parts":[{"shape":"Block","size":[1.3,1.25,0.6],"pos":[0,0.0,0.82],"rot":[0,0,0],"color":"C8202E","name":"Case"},{"shape":"Block","size":[1.32,0.6,0.05],"pos":[0,0.3,1.13],"rot":[0,0,0],"color":"A51A26","name":"Flap"},{"shape":"Block","size":[0.18,0.18,0.05],"pos":[0,0.05,1.165],"rot":[0,0,0],"color":"D4A52A","name":"Clasp"},{"shape":"Block","size":[0.2,1.1,0.05],"pos":[-0.45,0.2,-0.53],"rot":[0,0,0],"color":"C8202E","name":"StrapL"},{"shape":"Block","size":[0.2,1.1,0.05],"pos":[0.45,0.2,-0.53],"rot":[0,0,0],"color":"C8202E","name":"StrapR"}]},{"name":"ACC_Z3_Col","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[1.0,0.18,0.95],"pos":[0,0.82,0],"rot":[0,0,0],"color":"1E2433","name":"Collar"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0,0.55,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0,0.3,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0,0.05,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0,-0.2,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0,-0.45,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"}]}],"witness":true},{"name":"NPC_Witness_Z3_02","zone":3,"scale":1.0,"task":"L-111","body":{"Head":"E3BE98","UpperTorso":"2C3340","LowerTorso":"2C3340","RightUpperArm":"2C3340","LeftUpperArm":"2C3340","RightLowerArm":"2C3340","LeftLowerArm":"2C3340","RightHand":"E3BE98","LeftHand":"E3BE98","RightUpperLeg":"2C3340","LeftUpperLeg":"2C3340","RightLowerLeg":"2C3340","LeftLowerLeg":"2C3340","RightFoot":"101012","LeftFoot":"101012"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z3_CheveuxRaie","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"1A1A1E","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"1A1A1E","name":"Back"},{"shape":"Block","size":[0.7,0.16,0.12],"pos":[0.22,0.44,-0.57],"rot":[0,0,-12],"color":"1A1A1E","name":"Part"}]},{"name":"ACC_Z3_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.04,0.035,0.035],"pos":[0,0.25,-0.61],"rot":[0,0,0],"color":"1A1A1E","name":"Bar"},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[-0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensL","transparency":0.55},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensR","transparency":0.55},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"1A1A1E","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"1A1A1E","name":"TempleR"}]},{"name":"ACC_Z3_Chemise","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.46,0.6,0.04],"pos":[0,0.53,-0.515],"rot":[0,0,0],"color":"F7F7F7","name":"Shirt"},{"shape":"Block","size":[0.16,0.9,0.04],"pos":[0,0.32,-0.53],"rot":[0,0,0],"color":"2E5AA8","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"2E5AA8","name":"Knot"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[-0.25,0.47,-0.525],"rot":[0,0,-18],"color":"3A4250","name":"LapelL"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[0.25,0.47,-0.525],"rot":[0,0,18],"color":"3A4250","name":"LapelR"}]},{"name":"ACC_Z3_Mallette","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[1.1,0.8,0.28],"pos":[0,-0.7,0],"rot":[0,0,0],"color":"3A2A1E","name":"Case"},{"shape":"Block","size":[0.4,0.08,0.08],"pos":[0,-0.24,0],"rot":[0,0,0],"color":"1A1410","name":"Grip"},{"shape":"Block","size":[0.1,0.1,0.04],"pos":[-0.3,-0.42,-0.155],"rot":[0,0,0],"color":"D4A52A","name":"Clasp"},{"shape":"Block","size":[0.1,0.1,0.04],"pos":[0.3,-0.42,-0.155],"rot":[0,0,0],"color":"D4A52A","name":"Clasp"}]}],"witness":true},{"name":"NPC_Witness_Z4_01","zone":4,"scale":1.0,"task":"L-111","body":{"Head":"C98B5C","UpperTorso":"F7C548","LowerTorso":"2FA4C9","RightUpperArm":"C98B5C","LeftUpperArm":"C98B5C","RightLowerArm":"C98B5C","LeftLowerArm":"C98B5C","RightHand":"C98B5C","LeftHand":"C98B5C","RightUpperLeg":"2FA4C9","LeftUpperLeg":"2FA4C9","RightLowerLeg":"C98B5C","LeftLowerLeg":"C98B5C","RightFoot":"F2F2F2","LeftFoot":"F2F2F2"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z4_Cheveux","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"F2D27A","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"F2D27A","name":"Back"},{"shape":"Block","size":[1.22,0.2,0.1],"pos":[0,0.41,-0.57],"rot":[0,0,0],"color":"F2D27A","name":"Fringe"},{"shape":"Block","size":[0.3,0.26,0.14],"pos":[-0.35,0.36,-0.6],"rot":[0,0,20],"color":"F2D27A","name":"Lock"},{"shape":"Block","size":[0.3,0.26,0.14],"pos":[0.3,0.38,-0.6],"rot":[0,0,-15],"color":"F2D27A","name":"Lock"}]},{"name":"ACC_Z4_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.08,0.24,0.07],"pos":[0,0.13,-0.61],"rot":[0,0,0],"color":"101012","name":"Shades","reflectance":0.5},{"shape":"Block","size":[0.04,0.05,0.62],"pos":[-0.59,0.17,-0.3],"rot":[0,0,0],"color":"E8533A","name":"TempleL"},{"shape":"Block","size":[0.04,0.05,0.62],"pos":[0.59,0.17,-0.3],"rot":[0,0,0],"color":"E8533A","name":"TempleR"}]},{"name":"ACC_Z4_Collier","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.7,0.06,0.04],"pos":[0,0.66,-0.52],"rot":[0,0,0],"color":"F5F0E1","name":"Cord"},{"shape":"Ball","size":[0.18,0.18,0.18],"pos":[0,0.56,-0.53],"rot":[0,0,0],"color":"F2F2F2","name":"Shell"}]},{"name":"ACC_Z4_Skate","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,2.0,0.65],"pos":[0.15,-0.7,0],"rot":[0,0,0],"color":"2B2B2E","name":"Deck"},{"shape":"Block","size":[0.02,1.9,0.55],"pos":[0.22,-0.7,0],"rot":[0,0,0],"color":"E8533A","name":"Print"},{"shape":"Cylinder","size":[0.12,0.22,0.22],"pos":[0.3,0.05,0.2],"rot":[0,90,0],"color":"F2E14C","name":"Wheel"},{"shape":"Cylinder","size":[0.12,0.22,0.22],"pos":[0.3,0.05,-0.2],"rot":[0,90,0],"color":"F2E14C","name":"Wheel"},{"shape":"Cylinder","size":[0.12,0.22,0.22],"pos":[0.3,-1.45,0.2],"rot":[0,90,0],"color":"F2E14C","name":"Wheel"},{"shape":"Cylinder","size":[0.12,0.22,0.22],"pos":[0.3,-1.45,-0.2],"rot":[0,90,0],"color":"F2E14C","name":"Wheel"}]}],"witness":true},{"name":"NPC_Witness_Z4_02","zone":4,"scale":1.0,"task":"L-111","body":{"Head":"8D5524","UpperTorso":"E8417A","LowerTorso":"202024","RightUpperArm":"8D5524","LeftUpperArm":"8D5524","RightLowerArm":"8D5524","LeftLowerArm":"8D5524","RightHand":"8D5524","LeftHand":"8D5524","RightUpperLeg":"202024","LeftUpperLeg":"202024","RightLowerLeg":"202024","LeftLowerLeg":"202024","RightFoot":"F2F2F2","LeftFoot":"F2F2F2"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z4_Bandeau","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"2A1A10","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"2A1A10","name":"Back"},{"shape":"Cylinder","size":[0.2,1.27,1.27],"pos":[0,0.32,0],"rot":[0,0,90],"color":"F2F2F2","name":"Band"},{"shape":"Ball","size":[0.45,0.45,0.45],"pos":[0,0.4,0.66],"rot":[0,0,0],"color":"2A1A10","name":"Tie"},{"shape":"Block","size":[0.26,0.62,0.26],"pos":[0,0.06,0.74],"rot":[0,0,0],"color":"2A1A10","name":"Ponytail"}]},{"name":"ACC_Z4_Ecouteurs","attach":"FaceCenterAttachment","type":"Face","parts":[{"shape":"Block","size":[0.08,0.14,0.14],"pos":[0.6,-0.02,0.04],"rot":[0,0,0],"color":"F2F2F2","name":"BudR"},{"shape":"Block","size":[0.08,0.14,0.14],"pos":[-0.6,-0.02,0.04],"rot":[0,0,0],"color":"F2F2F2","name":"BudL"}]},{"name":"ACC_Z4_Gourde","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[0.75,0.3,0.3],"pos":[0,-0.42,-0.1],"rot":[0,0,90],"color":"3DB4E8","name":"Bottle"},{"shape":"Cylinder","size":[0.12,0.2,0.2],"pos":[0,-0.02,-0.1],"rot":[0,0,90],"color":"F2F2F2","name":"Cap"}]}],"witness":true},{"name":"NPC_Witness_Z5_01","zone":5,"scale":1.0,"task":"L-111","body":{"Head":"F1C9A5","UpperTorso":"F5F5F5","LowerTorso":"1D2A4A","RightUpperArm":"F5F5F5","LeftUpperArm":"F5F5F5","RightLowerArm":"F5F5F5","LeftLowerArm":"F5F5F5","RightHand":"F1C9A5","LeftHand":"F1C9A5","RightUpperLeg":"1D2A4A","LeftUpperLeg":"1D2A4A","RightLowerLeg":"1D2A4A","LeftLowerLeg":"1D2A4A","RightFoot":"3A2A20","LeftFoot":"3A2A20"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z5_Beret","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.2,1.36,1.36],"pos":[0.06,0.62,0.06],"rot":[0,0,84],"color":"15151A","name":"Beret","material":"Fabric"},{"shape":"Cylinder","size":[0.12,0.06,0.06],"pos":[0.08,0.76,0.06],"rot":[0,0,90],"color":"15151A","name":"Stalk"}]},{"name":"ACC_Z5_Mariniere","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.5,0.2,0.05],"pos":[0,0.76,-0.52],"rot":[0,0,0],"color":"C8202E","name":"Neckerchief"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,0.48,-0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,0.2,-0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.08,-0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.36,-0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.64,-0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,0.48,0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,0.2,0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.08,0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.36,0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"},{"shape":"Block","size":[1.96,0.12,0.04],"pos":[0,-0.64,0.515],"rot":[0,0,0],"color":"1D2A4A","name":"Stripe"}]},{"name":"ACC_Z5_Moustache","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[0.46,0.1,0.06],"pos":[0,-0.1,-0.6],"rot":[0,0,0],"color":"1E1410","name":"Center"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[-0.3,-0.06,-0.6],"rot":[0,0,-25],"color":"1E1410","name":"CurlL"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[0.3,-0.06,-0.6],"rot":[0,0,25],"color":"1E1410","name":"CurlR"}]},{"name":"ACC_Z5_Baguette","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[1.8,0.26,0.26],"pos":[0,-0.55,-0.05],"rot":[0,0,82],"color":"D9A45A","name":"Bread"},{"shape":"Block","size":[0.22,0.04,0.2],"pos":[0.0,-0.05,-0.17],"rot":[0,0,-20],"color":"F2D59A","name":"Cut"},{"shape":"Block","size":[0.22,0.04,0.2],"pos":[0.03,-0.4,-0.17],"rot":[0,0,-20],"color":"F2D59A","name":"Cut"},{"shape":"Block","size":[0.22,0.04,0.2],"pos":[0.06,-0.75,-0.17],"rot":[0,0,-20],"color":"F2D59A","name":"Cut"},{"shape":"Block","size":[0.22,0.04,0.2],"pos":[0.09,-1.1,-0.17],"rot":[0,0,-20],"color":"F2D59A","name":"Cut"}]}],"witness":true},{"name":"NPC_Witness_Z5_02","zone":5,"scale":1.0,"task":"L-111","body":{"Head":"F2D3BD","UpperTorso":"B3122E","LowerTorso":"B3122E","RightUpperArm":"B3122E","LeftUpperArm":"B3122E","RightLowerArm":"B3122E","LeftLowerArm":"B3122E","RightHand":"1A1A1E","LeftHand":"1A1A1E","RightUpperLeg":"1A1A1E","LeftUpperLeg":"1A1A1E","RightLowerLeg":"1A1A1E","LeftLowerLeg":"1A1A1E","RightFoot":"1A1A1E","LeftFoot":"1A1A1E"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z5_Carre","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"5A3420","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"5A3420","name":"Back"},{"shape":"Block","size":[1.22,0.2,0.1],"pos":[0,0.41,-0.57],"rot":[0,0,0],"color":"5A3420","name":"Fringe"},{"shape":"Block","size":[0.1,0.8,1.1],"pos":[-0.62,0.13,0.05],"rot":[0,0,0],"color":"5A3420","name":"Side"},{"shape":"Block","size":[0.1,0.8,1.1],"pos":[0.62,0.13,0.05],"rot":[0,0,0],"color":"5A3420","name":"Side"}]},{"name":"ACC_Z5_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.04,0.035,0.035],"pos":[0,0.25,-0.61],"rot":[0,0,0],"color":"1A1A1E","name":"Bar"},{"shape":"Block","size":[0.42,0.26,0.04],"pos":[-0.25,0.13,-0.605],"rot":[0,0,0],"color":"141416","name":"LensL","transparency":0.1},{"shape":"Block","size":[0.42,0.26,0.04],"pos":[0.25,0.13,-0.605],"rot":[0,0,0],"color":"141416","name":"LensR","transparency":0.1},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"1A1A1E","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"1A1A1E","name":"TempleR"}]},{"name":"ACC_Z5_Foulard","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[1.2,0.22,1.1],"pos":[0,0.8,0],"rot":[0,0,0],"color":"F2E3C6","name":"Wrap"},{"shape":"Block","size":[0.24,0.4,0.05],"pos":[-0.2,0.55,-0.54],"rot":[0,0,15],"color":"F2E3C6","name":"Knot"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0.3,0.1,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0.3,-0.25,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0.3,-0.6,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"}]},{"name":"ACC_Z5_Sac","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.75,0.55,0.3],"pos":[0,-0.62,0],"rot":[0,0,0],"color":"1A1A1E","name":"Bag"},{"shape":"Block","size":[0.45,0.06,0.06],"pos":[0,-0.2,0],"rot":[0,0,0],"color":"1A1A1E","name":"Strap"},{"shape":"Block","size":[0.12,0.1,0.04],"pos":[0,-0.48,-0.165],"rot":[0,0,0],"color":"D4A52A","name":"Clasp"}]}],"witness":true},{"name":"NPC_Witness_Z6_01","zone":6,"scale":1.0,"task":"L-111","body":{"Head":"C68E62","UpperTorso":"1F2A44","LowerTorso":"1F2A44","RightUpperArm":"1F2A44","LeftUpperArm":"1F2A44","RightLowerArm":"1F2A44","LeftLowerArm":"1F2A44","RightHand":"C68E62","LeftHand":"C68E62","RightUpperLeg":"1F2A44","LeftUpperLeg":"1F2A44","RightLowerLeg":"1F2A44","LeftLowerLeg":"1F2A44","RightFoot":"0B0B0D","LeftFoot":"0B0B0D"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z6_Cheveux","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.53,0.02],"rot":[0,0,0],"color":"2A1E16","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.13,0.56],"rot":[0,0,0],"color":"2A1E16","name":"Back"}]},{"name":"ACC_Z6_Chemise","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.46,0.6,0.04],"pos":[0,0.53,-0.515],"rot":[0,0,0],"color":"F7F7F7","name":"Shirt"},{"shape":"Block","size":[0.16,0.9,0.04],"pos":[0,0.32,-0.53],"rot":[0,0,0],"color":"B3122E","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"B3122E","name":"Knot"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[-0.25,0.47,-0.525],"rot":[0,0,-18],"color":"2A3550","name":"LapelL"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[0.25,0.47,-0.525],"rot":[0,0,18],"color":"2A3550","name":"LapelR"},{"shape":"Block","size":[0.22,0.1,0.04],"pos":[-0.55,0.32,-0.525],"rot":[0,0,0],"color":"F7F7F7","name":"PocketSquare"}]},{"name":"ACC_Z6_Cafe","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[0.4,0.3,0.3],"pos":[0,-0.42,-0.12],"rot":[0,0,90],"color":"F2F2F2","name":"Cup"},{"shape":"Cylinder","size":[0.13,0.31,0.31],"pos":[0,-0.45,-0.12],"rot":[0,0,90],"color":"8B5A2B","name":"Sleeve"},{"shape":"Cylinder","size":[0.05,0.32,0.32],"pos":[0,-0.205,-0.12],"rot":[0,0,90],"color":"3B2A20","name":"Lid"}]}],"witness":true},{"name":"NPC_Witness_Z6_02","zone":6,"scale":1.0,"task":"L-111","body":{"Head":"F2D3BD","UpperTorso":"F5F5F5","LowerTorso":"B8A47A","RightUpperArm":"F5F5F5","LeftUpperArm":"F5F5F5","RightLowerArm":"F2D3BD","LeftLowerArm":"F2D3BD","RightHand":"F2D3BD","LeftHand":"F2D3BD","RightUpperLeg":"B8A47A","LeftUpperLeg":"B8A47A","RightLowerLeg":"F2D3BD","LeftLowerLeg":"F2D3BD","RightFoot":"F2F2F2","LeftFoot":"F2F2F2"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z6_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.42,1.24,1.24],"pos":[0,0.5,0],"rot":[0,0,90],"color":"C8202E","name":"Crown"},{"shape":"Block","size":[0.98,0.07,0.56],"pos":[0,0.31,-0.83],"rot":[-10,0,0],"color":"A51A26","name":"Visor"},{"shape":"Cylinder","size":[0.06,0.16,0.16],"pos":[0,0.74,0],"rot":[0,0,90],"color":"C8202E","name":"Button"}]},{"name":"ACC_Z6_Tshirt","attach":"BodyFrontAttachment","type":"Front","text":"NEW YORK","textColor":"C8202E","textFace":"Front","textPart":"Print","parts":[{"shape":"Block","size":[1.6,0.62,0.03],"pos":[0,0.18,-0.512],"rot":[0,0,0],"color":"F5F5F5","name":"Print"},{"shape":"Block","size":[0.06,0.9,0.04],"pos":[-0.3,0.4,-0.53],"rot":[0,0,-30],"color":"2A2A2E","name":"Strap"},{"shape":"Block","size":[0.06,0.9,0.04],"pos":[0.3,0.4,-0.53],"rot":[0,0,30],"color":"2A2A2E","name":"Strap"},{"shape":"Block","size":[0.55,0.36,0.26],"pos":[0,-0.22,-0.66],"rot":[0,0,0],"color":"1A1A1E","name":"Camera"},{"shape":"Cylinder","size":[0.18,0.24,0.24],"pos":[0,-0.22,-0.84],"rot":[0,90,0],"color":"3A3A40","name":"Lens"}]},{"name":"ACC_Z6_Plan","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.9,0.7,0.04],"pos":[0,-0.45,-0.15],"rot":[10,0,0],"color":"E8DDA8","name":"Map"},{"shape":"Block","size":[0.3,0.06,0.045],"pos":[-0.1,-0.4,-0.18],"rot":[10,0,0],"color":"3DB4E8","name":"River"}]}],"witness":true}],"police":{"name":"NPC_Police","zone":0,"scale":1.12,"task":"L-111","body":{"Head":"E0AC7E","UpperTorso":"2A4A8C","LowerTorso":"0F1A33","RightUpperArm":"2A4A8C","LeftUpperArm":"2A4A8C","RightLowerArm":"2A4A8C","LeftLowerArm":"2A4A8C","RightHand":"E0AC7E","LeftHand":"E0AC7E","RightUpperLeg":"0F1A33","LeftUpperLeg":"0F1A33","RightLowerLeg":"0F1A33","LeftLowerLeg":"0F1A33","RightFoot":"0B0B0D","LeftFoot":"0B0B0D"},"accessories":[{"name":"ACC_Police_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.4,1.22,1.22],"pos":[0,0.5,0],"rot":[0,0,90],"color":"0F1A33","name":"Band"},{"shape":"Cylinder","size":[0.14,1.44,1.44],"pos":[0,0.74,-0.04],"rot":[0,0,90],"color":"0F1A33","name":"Top"},{"shape":"Cylinder","size":[0.08,1.235,1.235],"pos":[0,0.36,0],"rot":[0,0,90],"color":"0B0B0D","name":"BlackBand"},{"shape":"Block","size":[1.0,0.06,0.46],"pos":[0,0.31,-0.8],"rot":[-14,0,0],"color":"0B0B0D","name":"Visor","reflectance":0.3},{"shape":"Block","size":[0.24,0.26,0.05],"pos":[0,0.54,-0.63],"rot":[0,0,0],"color":"E5B53A","name":"Badge","material":"Metal"}]},{"name":"ACC_Police_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.02,0.035,0.035],"pos":[0,0.27,-0.61],"rot":[0,0,0],"color":"C9CED6","name":"Bar"},{"shape":"Block","size":[0.4,0.27,0.05],"pos":[-0.25,0.13,-0.605],"rot":[0,0,-8],"color":"1A1A1A","name":"LensL","reflectance":0.5},{"shape":"Block","size":[0.4,0.27,0.05],"pos":[0.25,0.13,-0.605],"rot":[0,0,8],"color":"1A1A1A","name":"LensR","reflectance":0.5},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"C9CED6","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"C9CED6","name":"TempleR"}]},{"name":"ACC_Police_Chemise","attach":"BodyFrontAttachment","type":"Front","text":"POLICE","textColor":"F2F2F2","textPart":"BackPanel","parts":[{"shape":"Block","size":[0.16,0.85,0.04],"pos":[0,0.34,-0.525],"rot":[0,0,0],"color":"0B0B0D","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"0B0B0D","name":"Knot"},{"shape":"Block","size":[0.46,0.34,0.04],"pos":[-0.5,0.16,-0.515],"rot":[0,0,0],"color":"22407C","name":"PocketL"},{"shape":"Block","size":[0.46,0.34,0.04],"pos":[0.5,0.16,-0.515],"rot":[0,0,0],"color":"22407C","name":"PocketR"},{"shape":"Block","size":[0.28,0.28,0.05],"pos":[0.5,0.42,-0.53],"rot":[0,0,0],"color":"E5B53A","name":"Star","material":"Metal"},{"shape":"Block","size":[0.28,0.28,0.05],"pos":[0.5,0.42,-0.535],"rot":[0,0,45],"color":"E5B53A","name":"Star2","material":"Metal"},{"shape":"Block","size":[0.4,0.1,0.05],"pos":[-0.5,0.4,-0.53],"rot":[0,0,0],"color":"C9CED6","name":"NameTag","material":"Metal"},{"shape":"Block","size":[1.7,0.62,0.04],"pos":[0,0.22,0.525],"rot":[0,0,0],"color":"2A4A8C","name":"BackPanel"}]},{"name":"ACC_Police_EcussonGauche","attach":"LeftShoulderAttachment","type":"Shoulder","parts":[{"shape":"Block","size":[0.05,0.36,0.3],"pos":[-0.52,0.3,0],"rot":[0,0,0],"color":"E5B53A","name":"Patch"}]},{"name":"ACC_Police_EcussonDroit","attach":"RightShoulderAttachment","type":"Shoulder","parts":[{"shape":"Block","size":[0.05,0.36,0.3],"pos":[0.52,0.3,0],"rot":[0,0,0],"color":"E5B53A","name":"Patch"}]},{"name":"ACC_Police_Ceinturon","attach":"WaistCenterAttachment","type":"Waist","parts":[{"shape":"Block","size":[2.02,0.18,1.06],"pos":[0,0.1,0],"rot":[0,0,0],"color":"111113","name":"Belt"},{"shape":"Block","size":[0.3,0.2,0.05],"pos":[0,0.1,-0.545],"rot":[0,0,0],"color":"C9CED6","name":"Buckle","material":"Metal"},{"shape":"Block","size":[0.24,0.42,0.16],"pos":[-0.78,-0.06,-0.58],"rot":[0,0,0],"color":"1A1A1D","name":"Radio"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[-0.85,0.3,-0.58],"rot":[0,0,0],"color":"111111","name":"Antenna"},{"shape":"Cylinder","size":[0.06,0.26,0.26],"pos":[0.48,0.0,-0.56],"rot":[0,90,0],"color":"C9CED6","name":"Cuff","material":"Metal"},{"shape":"Cylinder","size":[0.06,0.26,0.26],"pos":[0.66,0.0,-0.56],"rot":[0,90,0],"color":"C9CED6","name":"Cuff","material":"Metal"},{"shape":"Cylinder","size":[1.1,0.14,0.14],"pos":[0.98,-0.42,0.15],"rot":[0,0,90],"color":"1A1A1E","name":"Baton"}]}]},"rig":{"name":"Rig_Witness","zone":1,"scale":1.0,"task":"L-111","body":{"Head":"F1D1B5","UpperTorso":"9C6FB0","LowerTorso":"6B6F7A","RightUpperArm":"9C6FB0","LeftUpperArm":"9C6FB0","RightLowerArm":"9C6FB0","LeftLowerArm":"9C6FB0","RightHand":"F1D1B5","LeftHand":"F1D1B5","RightUpperLeg":"6B6F7A","LeftUpperLeg":"6B6F7A","RightLowerLeg":"CDB79E","LeftLowerLeg":"CDB79E","RightFoot":"4A3A30","LeftFoot":"4A3A30"},"accessories":[{"name":"ACC_Temoin_Telephone","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.12,0.86,0.48],"pos":[-0.55,-0.3,0],"rot":[0,0,0],"color":"1B1D22","name":"Body"},{"shape":"Block","size":[0.02,0.7,0.38],"pos":[-0.62,-0.3,0],"rot":[0,0,0],"color":"9BE3FF","name":"Screen","material":"Neon","transparency":0.2},{"shape":"Block","size":[0.02,0.05,0.16],"pos":[-0.62,0.08,0],"rot":[0,0,0],"color":"0E0F12","name":"Speaker"}]},{"name":"ACC_Z1_Chignon","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Block","size":[1.24,0.32,1.24],"pos":[0,0.55,0.02],"rot":[0,0,0],"color":"DADBE0","name":"Top"},{"shape":"Block","size":[1.24,0.72,0.16],"pos":[0,0.15,0.56],"rot":[0,0,0],"color":"DADBE0","name":"Back"},{"shape":"Block","size":[1.22,0.2,0.1],"pos":[0,0.41,-0.57],"rot":[0,0,0],"color":"DADBE0","name":"Fringe"},{"shape":"Ball","size":[0.55,0.55,0.55],"pos":[0,0.8,0.36],"rot":[0,0,0],"color":"DADBE0","name":"Bun"}]},{"name":"ACC_Z1_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.04,0.035,0.035],"pos":[0,0.25,-0.61],"rot":[0,0,0],"color":"9A7A3A","name":"Bar"},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[-0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensL","transparency":0.55},{"shape":"Block","size":[0.38,0.22,0.04],"pos":[0.25,0.13,-0.605],"rot":[0,0,0],"color":"CFE8F2","name":"LensR","transparency":0.55},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"9A7A3A","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"9A7A3A","name":"TempleR"}]},{"name":"ACC_Z1_Cabas","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Block","size":[0.95,0.85,0.5],"pos":[0,-0.85,0],"rot":[0,0,0],"color":"C8452E","name":"Bag"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[-0.25,-0.3,0],"rot":[0,0,0],"color":"7A2A1C","name":"HandleL"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[0.25,-0.3,0],"rot":[0,0,0],"color":"7A2A1C","name":"HandleR"},{"shape":"Block","size":[0.14,0.7,0.14],"pos":[0.22,-0.4,0.08],"rot":[0,0,-10],"color":"6DBB45","name":"Leek"},{"shape":"Block","size":[0.16,0.22,0.16],"pos":[0.27,-0.84,0.08],"rot":[0,0,-10],"color":"F2F2EA","name":"LeekWhite"}]}],"witness":true},"witnessHeadY":1.85}]==])
local KERB_GAP, AXIS_GAP = 1.8, 10

local function angles(r: { number }): CFrame
	return CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

local function offset(p: any): CFrame
	return CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * angles(p.rot)
end

-- Pose de repos : chaque pièce placée par son articulation depuis le HumanoidRootPart.
local function poseRest(model: Model, humanoid: Humanoid)
	local found = model:FindFirstChild("HumanoidRootPart")
	assert(found and found:IsA("BasePart"), `{model.Name} : HumanoidRootPart absent`)
	local root = found :: BasePart
	root.CFrame = CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local a0, a1 = d.Attachment0 :: Attachment, d.Attachment1 :: Attachment
			table.insert(joints, { p0 = a0.Parent, p1 = a1.Parent, c0 = a0.CFrame, c1 = a1.CFrame })
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = d.C0, c1 = d.C1 })
		end
	end
	local placed = { [root] = true }
	local moved = true
	while moved do
		moved = false
		for _, j in joints do
			if placed[j.p0] and not placed[j.p1] then
				j.p1.CFrame = j.p0.CFrame * j.c0 * j.c1:Inverse()
				placed[j.p1] = true
				moved = true
			end
		end
	end
end

local function bodyAttachment(model: Model, name: string): Attachment?
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local a = child:FindFirstChild(name)
			if a and a:IsA("Attachment") then
				return a
			end
		end
	end
	return nil
end

local function makePart(p: any, isHandle: boolean): Part
	local part = Instance.new("Part")
	part.Name = if isHandle then "Handle" else (p.name or "Part")
	part.Shape = if p.shape == "Ball"
		then Enum.PartType.Ball
		elseif p.shape == "Cylinder" then Enum.PartType.Cylinder
		else Enum.PartType.Block
	part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
	part.Color = Color3.fromHex(p.color)
	part.Material = (Enum.Material :: any)[p.material or "SmoothPlastic"]
	part.Reflectance = p.reflectance or 0
	part.Transparency = p.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	if p.light then
		-- lampe torche : éclaire vers l'avant de la pièce (face Front, -Z)
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Range = p.light.range
		light.Angle = p.light.angle
		light.Brightness = p.light.brightness
		light.Color = Color3.fromHex(p.light.color)
		light.Shadows = false
		light.Parent = part
	end
	return part
end

local function addText(part: BasePart, text: string, hex: string, face: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = if face == "Front" then "FrontPrint" else "BackPrint"
	gui.Face = if face == "Front" then Enum.NormalId.Front else Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Name = "Print"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.3)
	label.Position = UDim2.fromScale(0.05, 0.07)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromHex(hex)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.Parent = gui
	gui.Parent = part
end

local function addAccessory(model: Model, acc: any): string?
	local attach = bodyAttachment(model, acc.attach)
	if attach == nil then
		return `{acc.name} : attache {acc.attach} absente du rig`
	end
	local bodyPart = attach.Parent :: BasePart
	local accessory = Instance.new("Accessory")
	accessory.Name = acc.name
	accessory.AccessoryType = (Enum.AccessoryType :: any)[acc.type]
	local handleOffset = offset(acc.parts[1])
	local handle: Part? = nil
	local byName: { [string]: Part } = {}
	for i, p in acc.parts do
		local part = makePart(p, i == 1)
		local o = offset(p)
		part.CFrame = bodyPart.CFrame * o
		byName[p.name or ""] = part
		if i == 1 then
			handle = part
		else
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryPartWeld"
			weld.Part0 = handle
			weld.Part1 = part
			weld.C0 = handleOffset:Inverse() * o
			weld.Parent = part
		end
		part.Parent = accessory
	end
	local h = handle :: Part
	local handleAttach = Instance.new("Attachment")
	handleAttach.Name = acc.attach
	handleAttach.CFrame = handleOffset:Inverse() * attach.CFrame
	handleAttach.Parent = h
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = h
	weld.Part1 = bodyPart
	weld.C0 = handleAttach.CFrame
	weld.C1 = attach.CFrame
	weld.Parent = h
	if acc.text then
		addText(if acc.textPart then byName[acc.textPart] else h, acc.text, acc.textColor or "1B1B24", acc.textFace)
	end
	accessory.Parent = model
	return nil
end

local function buildNpc(g: any, report: { string }): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromHex(g.body.Head)
	desc.TorsoColor = Color3.fromHex(g.body.UpperTorso)
	desc.LeftArmColor = Color3.fromHex(g.body.LeftUpperArm)
	desc.RightArmColor = Color3.fromHex(g.body.RightUpperArm)
	desc.LeftLegColor = Color3.fromHex(g.body.LeftUpperLeg)
	desc.RightLegColor = Color3.fromHex(g.body.RightUpperLeg)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok then
		table.insert(report, `{g.name} : rig impossible ({result})`)
		return nil
	end
	local model = result :: Model
	model.Name = g.name
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{g.name} : Humanoid absent du rig`)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	if humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	for partName, hex in g.body do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = Color3.fromHex(hex)
		end
	end
	poseRest(model, humanoid)
	for _, acc in g.accessories do
		local err = addAccessory(model, acc)
		if err then
			table.insert(report, err)
		end
	end
	if g.witness then
		-- attache du billboard BB_Witness (« ? » puis « ! »), au-dessus de la tête et des chapeaux
		local head = model:FindFirstChild("Head")
		assert(head, `{g.name} : tête absente du rig`)
		local a = Instance.new("Attachment")
		a.Name = "WitnessHead"
		a.Position = Vector3.new(0, DATA.witnessHeadY, 0)
		a.Parent = head
	end
	model:ScaleTo(g.scale)
	return model
end

local report: { string } = {}

local function keepAnimations(old: Instance?, model: Model)
	local anims = old and old:FindFirstChild("Animations")
	if anims then
		anims.Parent = model
	end
end

local function standOn(model: Model, pos: Vector3, look: Vector3): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	assert(humanoid and root, `{model.Name} : Humanoid ou PrimaryPart absent`)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else pos.Y
	local p = Vector3.new(pos.X, floorY + humanoid.HipHeight + root.Size.Y / 2, pos.Z)
	model:PivotTo(CFrame.lookAt(p, Vector3.new(look.X, p.Y, look.Z)))
	return floorY
end

local function clearSpot(zone: Instance, pos: Vector3): string?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excl = {}
	local w = zone:FindFirstChild("Witnesses")
	if w then
		table.insert(excl, w)
	end
	params.FilterDescendantsInstances = excl
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0, 3.2, 0)), Vector3.new(2.6, 5.4, 2.6), params) do
		if part.Transparency < 1 and part.CanCollide then
			return part:GetFullName()
		end
	end
	return nil
end

-- Témoins ------------------------------------------------------------------------------------------------
local map = workspace:FindFirstChild("Map")
assert(map, "Workspace/Map absent")
for zoneIndex = 1, 6 do
	if DATA.onlyZones and not table.find(DATA.onlyZones, zoneIndex) then
		continue
	end
	local zone = map:FindFirstChild(`Zone_{zoneIndex}`)
	if zone == nil then
		table.insert(report, `Zone_{zoneIndex} absente`)
		continue
	end
	local stores = {}
	for _, s in zone:GetChildren() do
		if s:IsA("Model") and s.Name:match("^STORE_") and s:FindFirstChild("Window", true) then
			table.insert(stores, s)
		end
	end
	-- bord du trottoir côté chaussée : bordures Kerb_* et RedKerb_* de la rue de la zone
	local kerb = { [1] = 0, [-1] = 0 }
	for _, d in zone:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("Kerb_[NS]") and not d.Name:match("^Boulevard") and d.Size.Y < 2 then
			local side = if d.Position.Z > 0 then 1 else -1
			kerb[side] = math.max(kerb[side], math.abs(d.Position.Z) + d.Size.Z / 2)
		end
	end
	local folder = zone:FindFirstChild("Witnesses")
	if folder == nil then
		local f = Instance.new("Folder")
		f.Name = "Witnesses"
		f.Parent = zone
		folder = f
	end
	for _, store in stores do
		local win = store:FindFirstChild("Window", true)
		assert(win and win:IsA("BasePart"), `{store.Name} : Window absente`)
		local storeSide = if win.Position.Z > 0 then 1 else -1
		local index = if storeSide < 0 then 1 else 2
		local name = string.format("NPC_Witness_Z%d_%02d", zoneIndex, index)
		local g
		for _, n in DATA.witnesses do
			if n.name == name then
				g = n
			end
		end
		if g == nil then
			table.insert(report, `{name} : look absent des données`)
			continue
		end
		local model = buildNpc(g, report)
		if model == nil then
			continue
		end
		local side = -storeSide
		local z = side * (kerb[side] + KERB_GAP)
		local x0 = win.Position.X + side * AXIS_GAP
		local x, blocked = x0, nil
		for _, dx in { 0, 3, -3, 6, -6, 9, -9 } do
			blocked = clearSpot(zone, Vector3.new(x0 + dx, 0.5, z))
			if blocked == nil then
				x = x0 + dx
				break
			end
		end
		if blocked then
			table.insert(report, `{name} : place encombrée ({blocked}), posé quand même`)
		end
		local old = (folder :: Instance):FindFirstChild(name)
		keepAnimations(old, model)
		if old then
			old:Destroy()
		end
		local root = model.PrimaryPart :: BasePart
		root.Anchored = true
		model:SetAttribute("WatchedStore", store.Name)
		local floorY = standOn(model, Vector3.new(x, 0, z), win.Position)
		model.Parent = folder
		local dist = (Vector3.new(x, 0, z) - Vector3.new(win.Position.X, 0, win.Position.Z)).Magnitude
		table.insert(report, string.format("%s : (%.1f, %.2f, %.1f), regarde %s à %.0f studs, %s",
			name, x, floorY, z, store.Name, dist, if model:FindFirstChild("Animations") then "Animations gardées" else "sans Animations"))
		task.wait()
	end
end

-- Policier -----------------------------------------------------------------------------------------------
local assets = ReplicatedStorage:FindFirstChild("Assets")
local guards = assets and assets:FindFirstChild("Guards")
assert(guards, "ReplicatedStorage/Assets/Guards absent")
local police = if DATA.police then buildNpc(DATA.police, report) else nil
if police then
	local old = guards:FindFirstChild(police.Name)
	keepAnimations(old, police)
	if police:FindFirstChild("Animations") == nil then
		local z1 = guards:FindFirstChild("Guard_Z1")
		local src = z1 and z1:FindFirstChild("Animations")
		local f = Instance.new("Folder")
		f.Name = "Animations"
		for _, n in { "Idle", "Walk", "Run", "Catch", "Tired" } do
			local a = src and src:FindFirstChild(n)
			if a then
				a:Clone().Parent = f
			end
		end
		f.Parent = police
	end
	if old then
		old:Destroy()
	end
	local humanoid = police:FindFirstChildOfClass("Humanoid")
	local root = police.PrimaryPart
	assert(humanoid and root, "NPC_Police : Humanoid ou PrimaryPart absent")
	police:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	police.Parent = guards
	local t = {}
	local animFolder = police:FindFirstChild("Animations")
	for _, a in if animFolder then animFolder:GetChildren() else {} do
		table.insert(t, a.Name)
	end
	table.sort(t)
	local _, size = police:GetBoundingBox()
	table.insert(report, string.format("%s : échelle %.2f, %.2f studs de haut, Animations %s",
		police.Name, police:GetScale(), size.Y, table.concat(t, ", ")))
end

-- Rig de travail -----------------------------------------------------------------------------------------
local rigs = ServerStorage:FindFirstChild("AnimRigs")
if rigs and DATA.rig then
	local rig = buildNpc(DATA.rig, report)
	if rig then
		local old = rigs:FindFirstChild(DATA.rig.name)
		local at = if old and old:IsA("Model") then old:GetPivot() else CFrame.new(-84, 3.19, 0)
		local saves = old and old:FindFirstChild("AnimSaves")
		if saves then
			saves.Parent = rig
		end
		if old then
			old:Destroy()
		end
		rig:PivotTo(at)
		rig.Parent = rigs
		table.insert(report, `AnimRigs/{rig.Name} : rig de travail des témoins`)
	end
end
return table.concat(report, "\n")

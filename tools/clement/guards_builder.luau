--!strict
-- Constructeur des vigiles Guard_Z1 à Guard_Z6 (MOD-017, MOD-030), pour Clément.
-- À lancer dans Studio en mode Edit (barre de commande ou MCP). Relançable : remplace les
-- modèles et garde le dossier Animations déjà rempli.
--
-- Crée ReplicatedStorage/Assets/Guards/Guard_Z<n> : rig R15 standard de Roblox
-- (CreateHumanoidModelFromDescriptionAsync), Humanoid avec son Animator, couleurs du corps,
-- accessoires ACC_Z<n>_* (Accessory, Handle et attache du corps), dossier Animations, aucun
-- script, puis la taille du vigile (Model:ScaleTo, de 1 à 1,4).
-- Dans Workspace/_SHOWROOM_CLEMENT, remplace la silhouette grise du vigile par 6 copies
-- d'exposition sans Humanoid (Show_<nom>) sur leurs socles (Ped_<nom>), position x donnée par
-- les données (showX). Aussi le vigile de nuit commun NightGuard (MOD-032, liaison L-043).
--
-- Données générées depuis StealAShop-Art/Guards/_scripts/guards_data.py (make_luau.py).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DATA = HttpService:JSONDecode([==[{"guards":[{"name":"Guard_Z1","zone":1,"scale":1.0,"task":"MOD-017","body":{"Head":"EAB892","UpperTorso":"8FB8E8","LowerTorso":"2B3A55","RightUpperArm":"8FB8E8","LeftUpperArm":"8FB8E8","RightLowerArm":"EAB892","LeftLowerArm":"EAB892","RightHand":"EAB892","LeftHand":"EAB892","RightUpperLeg":"2B3A55","LeftUpperLeg":"2B3A55","RightLowerLeg":"2B3A55","LeftLowerLeg":"2B3A55","RightFoot":"1E1E22","LeftFoot":"1E1E22"},"accessories":[{"name":"ACC_Z1_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.42,1.24,1.24],"pos":[0,0.5,0],"rot":[0,0,90],"color":"1F2C4C","name":"Crown"},{"shape":"Block","size":[0.98,0.07,0.56],"pos":[0,0.31,-0.83],"rot":[-10,0,0],"color":"17213A","name":"Visor"},{"shape":"Cylinder","size":[0.06,0.16,0.16],"pos":[0,0.74,0],"rot":[0,0,90],"color":"1F2C4C","name":"Button"},{"shape":"Block","size":[0.32,0.22,0.05],"pos":[0,0.52,-0.625],"rot":[0,0,0],"color":"F2C230","name":"Badge"}]},{"name":"ACC_Z1_Gilet","attach":"BodyFrontAttachment","type":"Front","text":"SECURITY","textColor":"1B1B24","parts":[{"shape":"Block","size":[2.0,1.24,1.1],"pos":[0,-0.21,0],"rot":[0,0,0],"color":"D8F23A","name":"Vest"},{"shape":"Block","size":[0.4,0.48,1.1],"pos":[-0.52,0.62,0],"rot":[0,0,0],"color":"D8F23A","name":"StrapL"},{"shape":"Block","size":[0.4,0.48,1.1],"pos":[0.52,0.62,0],"rot":[0,0,0],"color":"D8F23A","name":"StrapR"},{"shape":"Block","size":[2.02,0.12,0.04],"pos":[0,-0.42,-0.565],"rot":[0,0,0],"color":"E4E8EE","name":"Stripe"},{"shape":"Block","size":[2.02,0.12,0.04],"pos":[0,-0.68,-0.565],"rot":[0,0,0],"color":"E4E8EE","name":"Stripe"},{"shape":"Block","size":[2.02,0.12,0.04],"pos":[0,-0.42,0.565],"rot":[0,0,0],"color":"E4E8EE","name":"Stripe"},{"shape":"Block","size":[2.02,0.12,0.04],"pos":[0,-0.68,0.565],"rot":[0,0,0],"color":"E4E8EE","name":"Stripe"}]},{"name":"ACC_Z1_Cafe","attach":"LeftGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[0.4,0.3,0.3],"pos":[0,-0.42,-0.12],"rot":[0,0,90],"color":"F2F2F2","name":"Cup"},{"shape":"Cylinder","size":[0.13,0.31,0.31],"pos":[0,-0.45,-0.12],"rot":[0,0,90],"color":"8B5A2B","name":"Sleeve"},{"shape":"Cylinder","size":[0.05,0.32,0.32],"pos":[0,-0.205,-0.12],"rot":[0,0,90],"color":"3B2A20","name":"Lid"}]},{"name":"ACC_Z1_Ceinture","attach":"WaistCenterAttachment","type":"Waist","parts":[{"shape":"Block","size":[2.02,0.16,1.06],"pos":[0,0.1,0],"rot":[0,0,0],"color":"1A1A1E","name":"Belt"},{"shape":"Block","size":[0.3,0.2,0.05],"pos":[0,0.1,-0.545],"rot":[0,0,0],"color":"C9A227","name":"Buckle"},{"shape":"Block","size":[0.24,0.42,0.16],"pos":[-0.78,-0.06,-0.58],"rot":[0,0,0],"color":"26262B","name":"Radio"},{"shape":"Block","size":[0.05,0.3,0.05],"pos":[-0.85,0.3,-0.58],"rot":[0,0,0],"color":"111111","name":"Antenna"},{"shape":"Cylinder","size":[0.55,0.17,0.17],"pos":[0.82,-0.1,-0.5],"rot":[0,0,90],"color":"3A3A40","name":"Torch"}]}],"showX":-106.5},{"name":"Guard_Z2","zone":2,"scale":1.08,"task":"MOD-030","body":{"Head":"F2D0B4","UpperTorso":"C8102E","LowerTorso":"C8102E","RightUpperArm":"C8102E","LeftUpperArm":"C8102E","RightLowerArm":"C8102E","LeftLowerArm":"C8102E","RightHand":"F4F4F4","LeftHand":"F4F4F4","RightUpperLeg":"16161D","LeftUpperLeg":"16161D","RightLowerLeg":"16161D","LeftLowerLeg":"16161D","RightFoot":"0F0F12","LeftFoot":"0F0F12"},"accessories":[{"name":"ACC_Z2_Bonnet","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[1.55,1.3,1.3],"pos":[0,1.02,0],"rot":[0,0,90],"color":"141416","name":"Fur","material":"Fabric"},{"shape":"Ball","size":[1.3,1.3,1.3],"pos":[0,1.62,0],"rot":[0,0,0],"color":"141416","name":"Dome","material":"Fabric"},{"shape":"Block","size":[0.05,0.72,0.07],"pos":[-0.6,-0.02,-0.12],"rot":[0,0,0],"color":"D4A52A","name":"StrapL"},{"shape":"Block","size":[0.05,0.72,0.07],"pos":[0.6,-0.02,-0.12],"rot":[0,0,0],"color":"D4A52A","name":"StrapR"},{"shape":"Block","size":[0.12,0.55,0.12],"pos":[-0.67,1.2,0.05],"rot":[0,0,0],"color":"C8102E","name":"Plume"}]},{"name":"ACC_Z2_Tunique","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[1.0,0.22,0.9],"pos":[0,0.8,0],"rot":[0,0,0],"color":"1C2550","name":"Collar"},{"shape":"Block","size":[1.02,0.05,0.92],"pos":[0,0.89,0],"rot":[0,0,0],"color":"D4A52A","name":"CollarTrim"},{"shape":"Block","size":[2.0,0.24,1.08],"pos":[0,-0.74,0],"rot":[0,0,0],"color":"F2F2F2","name":"Belt"},{"shape":"Block","size":[0.3,0.22,0.05],"pos":[0,-0.74,-0.565],"rot":[0,0,0],"color":"D4A52A","name":"Buckle"},{"shape":"Block","size":[0.13,0.13,0.05],"pos":[0,0.52,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.13,0.13,0.05],"pos":[0,0.3,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.13,0.13,0.05],"pos":[0,0.08,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.13,0.13,0.05],"pos":[0,-0.14,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.13,0.13,0.05],"pos":[0,-0.36,-0.527],"rot":[0,0,0],"color":"D4A52A","name":"Button"}]}],"showX":-97.5},{"name":"Guard_Z3","zone":3,"scale":1.16,"task":"MOD-030","body":{"Head":"E9C29F","UpperTorso":"35507A","LowerTorso":"1F2B42","RightUpperArm":"35507A","LeftUpperArm":"35507A","RightLowerArm":"35507A","LeftLowerArm":"35507A","RightHand":"F7F7F7","LeftHand":"F7F7F7","RightUpperLeg":"1F2B42","LeftUpperLeg":"1F2B42","RightLowerLeg":"1F2B42","LeftLowerLeg":"1F2B42","RightFoot":"141418","LeftFoot":"141418"},"accessories":[{"name":"ACC_Z3_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.34,1.22,1.22],"pos":[0,0.42,0],"rot":[0,0,90],"color":"1B2740","name":"Band"},{"shape":"Cylinder","size":[0.2,1.42,1.42],"pos":[0,0.66,-0.04],"rot":[0,0,90],"color":"1B2740","name":"Top"},{"shape":"Cylinder","size":[0.08,1.235,1.235],"pos":[0,0.3,0],"rot":[0,0,90],"color":"D9A62E","name":"GoldBand"},{"shape":"Block","size":[1.0,0.06,0.45],"pos":[0,0.27,-0.8],"rot":[-14,0,0],"color":"0E0E12","name":"Visor","reflectance":0.3},{"shape":"Block","size":[0.22,0.22,0.05],"pos":[0,0.5,-0.625],"rot":[0,0,45],"color":"D9A62E","name":"Emblem"}]},{"name":"ACC_Z3_Baudrier","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.2,2.05,0.05],"pos":[0,-0.05,-0.53],"rot":[0,0,33],"color":"C6F23E","name":"StrapA"},{"shape":"Block","size":[0.2,2.05,0.05],"pos":[0,-0.05,-0.535],"rot":[0,0,-33],"color":"C6F23E","name":"StrapB"},{"shape":"Block","size":[0.2,2.05,0.05],"pos":[0,-0.05,0.53],"rot":[0,0,33],"color":"C6F23E","name":"StrapC"},{"shape":"Block","size":[0.2,2.05,0.05],"pos":[0,-0.05,0.535],"rot":[0,0,-33],"color":"C6F23E","name":"StrapD"}]},{"name":"ACC_Z3_Baton","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[0.42,0.22,0.22],"pos":[0,-0.16,-0.05],"rot":[-20,90,0],"color":"1A1A1E","name":"Grip"},{"shape":"Cylinder","size":[1.3,0.19,0.19],"pos":[0,-0.454,-0.858],"rot":[-20,90,0],"color":"FF3030","name":"Light","material":"Neon","transparency":0.1}]}],"showX":-88.5},{"name":"Guard_Z4","zone":4,"scale":1.24,"task":"MOD-030","body":{"Head":"8D5524","UpperTorso":"1E1F24","LowerTorso":"34363D","RightUpperArm":"1E1F24","LeftUpperArm":"1E1F24","RightLowerArm":"8D5524","LeftLowerArm":"8D5524","RightHand":"141416","LeftHand":"141416","RightUpperLeg":"34363D","LeftUpperLeg":"34363D","RightLowerLeg":"34363D","LeftLowerLeg":"34363D","RightFoot":"8A6A45","LeftFoot":"8A6A45"},"accessories":[{"name":"ACC_Z4_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.42,1.24,1.24],"pos":[0,0.5,0],"rot":[0,0,90],"color":"151517","name":"Crown"},{"shape":"Block","size":[0.98,0.07,0.56],"pos":[0,0.31,-0.83],"rot":[-10,0,0],"color":"0E0E10","name":"Visor"},{"shape":"Cylinder","size":[0.06,0.16,0.16],"pos":[0,0.74,0],"rot":[0,0,90],"color":"151517","name":"Button"},{"shape":"Block","size":[0.26,0.26,0.05],"pos":[0,0.52,-0.625],"rot":[0,0,45],"color":"E2B13C","name":"Star"},{"shape":"Block","size":[0.26,0.26,0.05],"pos":[0,0.52,-0.63],"rot":[0,0,0],"color":"E2B13C","name":"Star2"}]},{"name":"ACC_Z4_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.02,0.035,0.035],"pos":[0,0.27,-0.61],"rot":[0,0,0],"color":"D9B44A","name":"Bar"},{"shape":"Block","size":[0.4,0.27,0.05],"pos":[-0.25,0.13,-0.605],"rot":[0,0,-8],"color":"1A1A1A","name":"LensL","reflectance":0.5},{"shape":"Block","size":[0.4,0.27,0.05],"pos":[0.25,0.13,-0.605],"rot":[0,0,8],"color":"1A1A1A","name":"LensR","reflectance":0.5},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[-0.585,0.22,-0.3],"rot":[0,0,0],"color":"D9B44A","name":"TempleL"},{"shape":"Block","size":[0.035,0.035,0.62],"pos":[0.585,0.22,-0.3],"rot":[0,0,0],"color":"D9B44A","name":"TempleR"}]},{"name":"ACC_Z4_Gilet","attach":"BodyFrontAttachment","type":"Front","text":"SECURITY","textColor":"F2F2F2","textPart":"BackPlate","parts":[{"shape":"Block","size":[1.72,1.1,0.2],"pos":[0,-0.14,-0.58],"rot":[0,0,0],"color":"2B2E25","name":"FrontPlate"},{"shape":"Block","size":[1.72,1.1,0.2],"pos":[0,-0.14,0.58],"rot":[0,0,0],"color":"2B2E25","name":"BackPlate"},{"shape":"Block","size":[0.1,0.5,1.18],"pos":[-0.92,-0.35,0],"rot":[0,0,0],"color":"2B2E25","name":"SideL"},{"shape":"Block","size":[0.1,0.5,1.18],"pos":[0.92,-0.35,0],"rot":[0,0,0],"color":"2B2E25","name":"SideR"},{"shape":"Block","size":[0.3,0.5,1.16],"pos":[-0.55,0.62,0],"rot":[0,0,0],"color":"2B2E25","name":"StrapL"},{"shape":"Block","size":[0.3,0.5,1.16],"pos":[0.55,0.62,0],"rot":[0,0,0],"color":"2B2E25","name":"StrapR"},{"shape":"Block","size":[0.44,0.36,0.16],"pos":[-0.52,-0.52,-0.74],"rot":[0,0,0],"color":"3A3D30","name":"Pouch"},{"shape":"Block","size":[0.44,0.36,0.16],"pos":[0,-0.52,-0.74],"rot":[0,0,0],"color":"3A3D30","name":"Pouch"},{"shape":"Block","size":[0.44,0.36,0.16],"pos":[0.52,-0.52,-0.74],"rot":[0,0,0],"color":"3A3D30","name":"Pouch"},{"shape":"Block","size":[0.26,0.3,0.05],"pos":[0.45,0.18,-0.705],"rot":[0,0,0],"color":"E2B13C","name":"Badge"},{"shape":"Block","size":[0.2,0.4,0.14],"pos":[-0.45,0.16,-0.75],"rot":[0,0,0],"color":"151517","name":"Radio"},{"shape":"Block","size":[0.05,0.28,0.05],"pos":[-0.5,0.5,-0.75],"rot":[0,0,0],"color":"0E0E10","name":"Antenna"}]},{"name":"ACC_Z4_Ceinture","attach":"WaistCenterAttachment","type":"Waist","parts":[{"shape":"Block","size":[2.02,0.16,1.06],"pos":[0,0.1,0],"rot":[0,0,0],"color":"111113","name":"Belt"},{"shape":"Block","size":[0.28,0.18,0.05],"pos":[0,0.1,-0.545],"rot":[0,0,0],"color":"8A8A90","name":"Buckle"},{"shape":"Block","size":[0.26,0.3,0.16],"pos":[-0.75,-0.05,-0.56],"rot":[0,0,0],"color":"1A1A1D","name":"Pouch"},{"shape":"Cylinder","size":[0.55,0.17,0.17],"pos":[0.8,-0.1,-0.5],"rot":[0,0,90],"color":"2A2A2E","name":"Torch"}]}],"showX":-79.5},{"name":"Guard_Z5","zone":5,"scale":1.32,"task":"MOD-030","body":{"Head":"F1C9A5","UpperTorso":"1D2A4A","LowerTorso":"18223D","RightUpperArm":"1D2A4A","LeftUpperArm":"1D2A4A","RightLowerArm":"1D2A4A","LeftLowerArm":"1D2A4A","RightHand":"FAFAFA","LeftHand":"FAFAFA","RightUpperLeg":"18223D","LeftUpperLeg":"18223D","RightLowerLeg":"18223D","LeftLowerLeg":"18223D","RightFoot":"0D0D10","LeftFoot":"0D0D10"},"accessories":[{"name":"ACC_Z5_Kepi","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.66,1.2,1.2],"pos":[0,0.62,0.02],"rot":[0,0,90],"color":"1D2A4A","name":"Body"},{"shape":"Cylinder","size":[0.06,1.21,1.21],"pos":[0,0.96,0.02],"rot":[0,0,90],"color":"B3122E","name":"Top"},{"shape":"Cylinder","size":[0.1,1.215,1.215],"pos":[0,0.36,0.02],"rot":[0,0,90],"color":"D4A52A","name":"GoldBand"},{"shape":"Block","size":[0.96,0.05,0.4],"pos":[0,0.3,-0.78],"rot":[-12,0,0],"color":"0E0E10","name":"Visor"},{"shape":"Block","size":[0.18,0.24,0.05],"pos":[0,0.64,-0.605],"rot":[0,0,0],"color":"D4A52A","name":"Emblem"}]},{"name":"ACC_Z5_Veste","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.46,0.55,0.04],"pos":[0,0.55,-0.515],"rot":[0,0,0],"color":"F5F5F5","name":"Shirt"},{"shape":"Block","size":[0.16,0.8,0.04],"pos":[0,0.36,-0.53],"rot":[0,0,0],"color":"B3122E","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"B3122E","name":"Knot"},{"shape":"Block","size":[0.1,0.7,0.04],"pos":[-0.24,0.48,-0.525],"rot":[0,0,-18],"color":"15203A","name":"LapelL"},{"shape":"Block","size":[0.1,0.7,0.04],"pos":[0.24,0.48,-0.525],"rot":[0,0,18],"color":"15203A","name":"LapelR"},{"shape":"Block","size":[0.24,0.12,0.04],"pos":[-0.55,0.3,-0.525],"rot":[0,0,0],"color":"B3122E","name":"PocketSquare"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[-0.2,-0.18,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0.2,-0.18,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[-0.2,-0.48,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"},{"shape":"Block","size":[0.12,0.12,0.05],"pos":[0.2,-0.48,-0.53],"rot":[0,0,0],"color":"D4A52A","name":"Button"}]},{"name":"ACC_Z5_EpauletteGauche","attach":"LeftShoulderAttachment","type":"Shoulder","parts":[{"shape":"Block","size":[0.7,0.1,0.8],"pos":[0,0.64,0],"rot":[0,0,0],"color":"D4A52A","name":"Board"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[-0.37,0.52,-0.3],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[-0.37,0.52,-0.1],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[-0.37,0.52,0.1],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[-0.37,0.52,0.3],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"}]},{"name":"ACC_Z5_EpauletteDroite","attach":"RightShoulderAttachment","type":"Shoulder","parts":[{"shape":"Block","size":[0.7,0.1,0.8],"pos":[0,0.64,0],"rot":[0,0,0],"color":"D4A52A","name":"Board"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[0.37,0.52,-0.3],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[0.37,0.52,-0.1],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[0.37,0.52,0.1],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"},{"shape":"Block","size":[0.07,0.22,0.07],"pos":[0.37,0.52,0.3],"rot":[0,0,0],"color":"D4A52A","name":"Fringe"}]},{"name":"ACC_Z5_Moustache","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[0.46,0.1,0.06],"pos":[0,-0.1,-0.6],"rot":[0,0,0],"color":"4A3220","name":"Center"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[-0.3,-0.06,-0.6],"rot":[0,0,-25],"color":"4A3220","name":"CurlL"},{"shape":"Block","size":[0.2,0.08,0.06],"pos":[0.3,-0.06,-0.6],"rot":[0,0,25],"color":"4A3220","name":"CurlR"}]}],"showX":-70.5},{"name":"Guard_Z6","zone":6,"scale":1.4,"task":"MOD-030","body":{"Head":"5A3A22","UpperTorso":"15151A","LowerTorso":"15151A","RightUpperArm":"15151A","LeftUpperArm":"15151A","RightLowerArm":"15151A","LeftLowerArm":"15151A","RightHand":"0F0F12","LeftHand":"0F0F12","RightUpperLeg":"15151A","LeftUpperLeg":"15151A","RightLowerLeg":"15151A","LeftLowerLeg":"15151A","RightFoot":"0B0B0D","LeftFoot":"0B0B0D"},"accessories":[{"name":"ACC_Z6_Chemise","attach":"BodyFrontAttachment","type":"Front","parts":[{"shape":"Block","size":[0.46,0.6,0.04],"pos":[0,0.53,-0.515],"rot":[0,0,0],"color":"F7F7F7","name":"Shirt"},{"shape":"Block","size":[0.16,0.9,0.04],"pos":[0,0.32,-0.53],"rot":[0,0,0],"color":"0B0B0D","name":"Tie"},{"shape":"Block","size":[0.2,0.14,0.06],"pos":[0,0.76,-0.535],"rot":[0,0,0],"color":"0B0B0D","name":"Knot"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[-0.25,0.47,-0.525],"rot":[0,0,-18],"color":"2A2A31","name":"LapelL"},{"shape":"Block","size":[0.1,0.75,0.04],"pos":[0.25,0.47,-0.525],"rot":[0,0,18],"color":"2A2A31","name":"LapelR"},{"shape":"Block","size":[0.26,0.32,0.05],"pos":[0.55,0.2,-0.53],"rot":[0,0,0],"color":"E5B53A","name":"Badge"},{"shape":"Block","size":[0.22,0.1,0.04],"pos":[-0.55,0.32,-0.525],"rot":[0,0,0],"color":"F7F7F7","name":"PocketSquare"},{"shape":"Block","size":[0.11,0.11,0.05],"pos":[0,-0.25,-0.53],"rot":[0,0,0],"color":"2E2E36","name":"Button"},{"shape":"Block","size":[0.11,0.11,0.05],"pos":[0,-0.52,-0.53],"rot":[0,0,0],"color":"2E2E36","name":"Button"}]},{"name":"ACC_Z6_Lunettes","attach":"FaceFrontAttachment","type":"Face","parts":[{"shape":"Block","size":[1.08,0.24,0.07],"pos":[0,0.13,-0.61],"rot":[0,0,0],"color":"0A0A0C","name":"Shades","reflectance":0.6},{"shape":"Block","size":[0.04,0.05,0.62],"pos":[-0.59,0.17,-0.3],"rot":[0,0,0],"color":"0A0A0C","name":"TempleL"},{"shape":"Block","size":[0.04,0.05,0.62],"pos":[0.59,0.17,-0.3],"rot":[0,0,0],"color":"0A0A0C","name":"TempleR"}]},{"name":"ACC_Z6_Oreillette","attach":"FaceCenterAttachment","type":"Face","parts":[{"shape":"Block","size":[0.08,0.14,0.14],"pos":[0.6,-0.02,0.04],"rot":[0,0,0],"color":"1A1A1A","name":"Bud"},{"shape":"Cylinder","size":[0.62,0.04,0.04],"pos":[0.57,-0.4,0.18],"rot":[0,0,90],"color":"BFC6CE","name":"Cord","transparency":0.25}]}],"showX":-61.5},{"name":"NightGuard","zone":0,"scale":1.1,"task":"MOD-032","body":{"Head":"C68E62","UpperTorso":"1C2436","LowerTorso":"121418","RightUpperArm":"1C2436","LeftUpperArm":"1C2436","RightLowerArm":"1C2436","LeftLowerArm":"1C2436","RightHand":"141418","LeftHand":"141418","RightUpperLeg":"121418","LeftUpperLeg":"121418","RightLowerLeg":"121418","LeftLowerLeg":"121418","RightFoot":"0B0B0D","LeftFoot":"0B0B0D"},"accessories":[{"name":"ACC_Nuit_Casquette","attach":"HatAttachment","type":"Hat","parts":[{"shape":"Cylinder","size":[0.42,1.24,1.24],"pos":[0,0.5,0],"rot":[0,0,90],"color":"111318","name":"Crown"},{"shape":"Block","size":[0.98,0.07,0.56],"pos":[0,0.31,-0.83],"rot":[-10,0,0],"color":"0B0C0F","name":"Visor"},{"shape":"Cylinder","size":[0.06,0.16,0.16],"pos":[0,0.74,0],"rot":[0,0,90],"color":"111318","name":"Button"},{"shape":"Block","size":[0.3,0.24,0.05],"pos":[0,0.52,-0.625],"rot":[0,0,0],"color":"C9CED6","name":"Badge","material":"Metal"}]},{"name":"ACC_Nuit_Gilet","attach":"BodyFrontAttachment","type":"Front","text":"SECURITY","textColor":"E8EEF5","textPart":"BackPanel","parts":[{"shape":"Block","size":[2.02,0.1,0.04],"pos":[0,-0.38,-0.53],"rot":[0,0,0],"color":"BFD3E6","name":"Stripe","material":"Neon","transparency":0.15},{"shape":"Block","size":[2.02,0.1,0.04],"pos":[0,-0.62,-0.53],"rot":[0,0,0],"color":"BFD3E6","name":"Stripe","material":"Neon","transparency":0.15},{"shape":"Block","size":[2.02,0.1,0.04],"pos":[0,-0.38,0.53],"rot":[0,0,0],"color":"BFD3E6","name":"Stripe","material":"Neon","transparency":0.15},{"shape":"Block","size":[2.02,0.1,0.04],"pos":[0,-0.62,0.53],"rot":[0,0,0],"color":"BFD3E6","name":"Stripe","material":"Neon","transparency":0.15},{"shape":"Block","size":[1.7,0.62,0.04],"pos":[0,0.22,0.525],"rot":[0,0,0],"color":"1C2436","name":"BackPanel"},{"shape":"Block","size":[0.24,0.3,0.05],"pos":[0.45,0.25,-0.53],"rot":[0,0,0],"color":"C9CED6","name":"Badge","material":"Metal"},{"shape":"Block","size":[0.2,0.38,0.14],"pos":[-0.45,0.25,-0.58],"rot":[0,0,0],"color":"111214","name":"Radio"}]},{"name":"ACC_Nuit_LampeTorche","attach":"RightGripAttachment","type":"Front","parts":[{"shape":"Cylinder","size":[0.9,0.22,0.22],"pos":[0,-0.16,-0.25],"rot":[0,90,0],"color":"1A1B1F","name":"Body"},{"shape":"Cylinder","size":[0.3,0.36,0.36],"pos":[0,-0.16,-0.85],"rot":[0,90,0],"color":"2A2C31","name":"Head"},{"shape":"Block","size":[0.3,0.3,0.04],"pos":[0,-0.16,-1.005],"rot":[0,0,0],"color":"FFF4D6","name":"Lens","material":"Neon","light":{"range":40,"angle":90,"brightness":2,"color":"FFF4D6"}}]}],"showX":-52.5}]}]==])

local SHOW_Z = 280
local DELIVERED_COLOR = Color3.fromHex("35DC5A") -- statut « LIVRÉ » des autres socles

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

local function addText(part: BasePart, text: string, hex: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BackPrint"
	gui.Face = Enum.NormalId.Back
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
		addText(if acc.textPart then byName[acc.textPart] else h, acc.text, acc.textColor or "1B1B24")
	end
	accessory.Parent = model
	return nil
end

local function buildGuard(g: any, folder: Folder, report: { string }): Model?
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
	local foundHumanoid = model:FindFirstChildOfClass("Humanoid")
	if foundHumanoid == nil then
		table.insert(report, `{g.name} : Humanoid absent du rig`)
		model:Destroy()
		return nil
	end
	local humanoid = foundHumanoid :: Humanoid
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
	-- Dossier Animations : celui du modèle remplacé s'il existe (objets Animation déjà posés).
	local old = folder:FindFirstChild(g.name)
	local anims = old and old:FindFirstChild("Animations")
	if anims then
		anims.Parent = model
	else
		local f = Instance.new("Folder")
		f.Name = "Animations"
		f.Parent = model
	end
	model:ScaleTo(g.scale)
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	if old then
		old:Destroy()
	end
	model.Parent = folder
	return model
end

local byName: { [string]: any } = {}
for _, g in DATA.guards do
	byName[g.name] = g
end

local function showroom(models: { Model }, report: { string })
	local show = workspace:FindFirstChild("_SHOWROOM_CLEMENT")
	local row = show and show:FindFirstChild("BASE ET BOUTIQUES")
	if row == nil then
		table.insert(report, "showroom : rangée BASE ET BOUTIQUES absente")
		return
	end
	local model0 = row:FindFirstChild("Ped_Vigile zone 1") or row:FindFirstChild("Ped_Guard_Z1")
	if model0 == nil or not model0:IsA("BasePart") then
		table.insert(report, "showroom : socle du vigile introuvable")
		return
	end
	local pedTemplate = model0:Clone()
	for _, name in { "Show_8", "Ped_Vigile zone 1" } do
		local o = row:FindFirstChild(name)
		if o then
			o:Destroy()
		end
	end
	for _, model in models do
		for _, name in { `Ped_{model.Name}`, `Show_{model.Name}` } do
			local o = row:FindFirstChild(name)
			if o then
				o:Destroy()
			end
		end
	end
	for _, template in models do
		local g = byName[template.Name]
		local humanoid = template:FindFirstChildOfClass("Humanoid")
		local root = template.PrimaryPart
		if humanoid == nil or root == nil then
			table.insert(report, `showroom : {template.Name} sans Humanoid ou PrimaryPart`)
			continue
		end
		local x = g.showX
		local ped = pedTemplate:Clone()
		ped.Name = `Ped_{template.Name}`
		ped.Size = Vector3.new(3.4 * g.scale, 1, 3.4 * g.scale)
		ped.CFrame = CFrame.new(x, 0.5, SHOW_Z)
		local label = ped:FindFirstChild("ShowLabel")
		if label and label:IsA("BillboardGui") then
			local _, size = template:GetBoundingBox()
			label.StudsOffset = Vector3.new(0, size.Y + 1.6, 0)
			local title = label:FindFirstChild("Title")
			local status = label:FindFirstChild("Status")
			if title and title:IsA("TextLabel") then
				title.Text = template.Name
			end
			if status and status:IsA("TextLabel") then
				status.Text = `LIVRÉ · {g.task}`
				status.TextColor3 = DELIVERED_COLOR
			end
		end
		ped.Parent = row
		local copy = template:Clone()
		copy.Name = `Show_{template.Name}`
		local rootHeight = humanoid.HipHeight + root.Size.Y / 2
		for _, d in copy:GetDescendants() do
			if d:IsA("Humanoid") or (d:IsA("Folder") and d.Name == "Animations") then
				d:Destroy()
			end
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			elseif d:IsA("Accessory") then
				d.Name = `Show_{d.Name}`
			end
		end
		copy:PivotTo(CFrame.new(x, 1 + rootHeight, SHOW_Z))
		copy.Parent = row
	end
	pedTemplate:Destroy()
end

local report: { string } = {}
local assets = ReplicatedStorage:FindFirstChild("Assets")
assert(assets, "ReplicatedStorage/Assets absent")
local existing = assets:FindFirstChild("Guards")
local folder: Folder
if existing and existing:IsA("Folder") then
	folder = existing
else
	folder = Instance.new("Folder")
	folder.Name = "Guards"
	folder.Parent = assets
end
local models: { Model } = {}
for _, g in DATA.guards do
	local model = buildGuard(g, folder, report)
	if model then
		table.insert(models, model)
		local _, size = model:GetBoundingBox()
		local hum = model:FindFirstChildOfClass("Humanoid")
		local hip = if hum then hum.HipHeight else 0
		local accs = 0
		for _, c in model:GetChildren() do
			if c:IsA("Accessory") then
				accs += 1
			end
		end
		table.insert(report, string.format("%s : échelle %.2f, %.2f studs de haut, HipHeight %.2f, %d accessoires",
			model.Name, model:GetScale(), size.Y, hip, accs))
	end
	task.wait()
end
if #models == #DATA.guards then
	showroom(models, report)
end
return table.concat(report, "\n")

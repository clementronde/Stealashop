--!strict
-- Ragdoll d'un personnage R15, commun au serveur (a503, 26/11) : sorti tel quel de GlassThrowService (a315), qui
-- l'utilise toujours, et repris par BatService (coup de batte libre dans le couloir, Features.BatFreePvP). Serveur
-- seulement : rien ici ne lit ni n'écrit d'argent, de stats ou de remote.
--
-- Apply : chaque Motor6D actif (sauf Root et Neck : le Neck coupé tue le Humanoid) est coupé et remplacé par une
-- BallSocketConstraint entre deux Attachment placés à ses C0 et C1, avec les angles de `settings` ; les membres
-- heurtent le sol (CanCollide à true, sauf le HumanoidRootPart). Tout ce qui est posé s'appelle `settings.Name`.
-- Restore : tout est retiré, les Motor6D rallumés et les CanCollide rendus tels qu'ils étaient.
-- SetOwner : propriétaire réseau des pièces libres du personnage (nil = le serveur simule).
--
-- API :
--   Ragdoll.Apply(character, root, settings, state)   remplit state.Joints et state.Collide
--   Ragdoll.Restore(state)                             les vide
--   Ragdoll.SetOwner(character, owner?)

export type Joint = { Motor: Motor6D, Made: { Instance } }
export type State = { Joints: { Joint }, Collide: { [BasePart]: boolean } }
export type Settings = { Name: string, UpperAngle: number, Twist: number }

local Ragdoll = {}

function Ragdoll.Apply(character: Model, root: BasePart, settings: Settings, state: State)
	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") or motor.Name == "Root" or motor.Name == "Neck" then
			continue
		end
		local m = motor :: Motor6D
		local part0, part1 = m.Part0, m.Part1
		if part0 == nil or part1 == nil or not m.Enabled then
			continue
		end
		local a0 = Instance.new("Attachment")
		a0.Name = settings.Name
		a0.CFrame = m.C0
		a0.Parent = part0
		local a1 = Instance.new("Attachment")
		a1.Name = settings.Name
		a1.CFrame = m.C1
		a1.Parent = part1
		local socket = Instance.new("BallSocketConstraint")
		socket.Name = settings.Name
		socket.Attachment0 = a0
		socket.Attachment1 = a1
		socket.LimitsEnabled = true
		socket.UpperAngle = settings.UpperAngle
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -settings.Twist
		socket.TwistUpperAngle = settings.Twist
		socket.Parent = part0
		m.Enabled = false
		table.insert(state.Joints, { Motor = m, Made = { socket, a0, a1 } })
	end
	-- Les membres heurtent le sol (le Humanoid les laisse traverser d'habitude).
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			local p = part :: BasePart
			state.Collide[p] = p.CanCollide
			p.CanCollide = true
		end
	end
end

function Ragdoll.Restore(state: State)
	for _, joint in state.Joints do
		for _, made in joint.Made do
			made:Destroy()
		end
		if joint.Motor.Parent ~= nil then
			joint.Motor.Enabled = true
		end
	end
	table.clear(state.Joints)
	for part, collide in state.Collide do
		if part.Parent ~= nil then
			part.CanCollide = collide
		end
	end
	table.clear(state.Collide)
end

function Ragdoll.SetOwner(character: Model, owner: Player?)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not (part :: BasePart).Anchored then
			pcall(function()
				(part :: BasePart):SetNetworkOwner(owner)
			end)
		end
	end
end

return Ragdoll

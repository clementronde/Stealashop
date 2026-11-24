--!nocheck
-- Banc a318, TrapController : un piège de boutique sort du streaming et revient. Une seule écoute de TrapState par
-- piège ; déclenché puis sorti, revenu (en gardant ou en perdant les changements locaux), puis réarmé : ses effets de
-- Armed se rallument (avant a318 : relus éteints au retour, ils restaient éteints).
local Traps = requireModule(ReplicatedStorage.Shared.Config.Traps)
local function buildTrap(name)
	local trap = model({ Name = name }, map())
	trap:SetAttribute(Traps.StateAttribute, Traps.Armed)
	local base = part({ Name = "Base" }, trap)
	local armed = model({ Name = "Armed" }, trap)
	local spikes = part({ Name = "Spikes" }, armed)
	local glow = newInstance("ParticleEmitter", { Name = "Glow", Enabled = true }, spikes)
	local light = newInstance("PointLight", { Name = "Light", Enabled = true }, spikes)
	local triggered = model({ Name = "Triggered" }, trap)
	local net = part({ Name = "Net", Transparency = 1 }, triggered)
	trap:AddTag(Traps.Tag)
	snapshot(trap)
	return trap, spikes, glow, light, net
end

scenario("trap")
local trap, spikes, glow, light, netPart = buildTrap("Trap_1")
startClientPhase()
startController("TrapController")
local signal = trap:GetAttributeChangedSignal(Traps.StateAttribute)
check(liveConnections(signal) == 1, `au départ : une écoute de {Traps.StateAttribute} ({liveConnections(signal)})`)
check(glow.Enabled and light.Enabled and spikes.LocalTransparencyModifier == 0, "armé : Armed visible et allumé")
cycles(trap, 5, false)
check(liveConnections(signal) == 1, `5 sorties et retours : toujours une écoute ({liveConnections(signal)})`)

for _, lose in { false, true } do
	local how = if lose then "en perdant les changements locaux" else "en les gardant"
	trap:SetAttribute(Traps.StateAttribute, Traps.Triggered)
	advance(0.1)
	check(not glow.Enabled and not light.Enabled and spikes.LocalTransparencyModifier == 1, `déclenché : Armed caché et éteint ({how})`)
	check(netPart.Transparency == 0, "déclenché : Triggered montré")
	streamOut(trap)
	advance(0.2)
	streamIn(trap, lose)
	advance(0.2)
	check(not glow.Enabled and not light.Enabled and spikes.LocalTransparencyModifier == 1, `revenu toujours déclenché : Armed caché et éteint ({how})`)
	trap:SetAttribute(Traps.StateAttribute, Traps.Armed)
	advance(0.1)
	check(glow.Enabled and light.Enabled and spikes.LocalTransparencyModifier == 0, `réarmé après le retour : Armed visible et rallumé ({how})`)
	check(netPart.Transparency == 1, `réarmé : Triggered caché ({how})`)
	check(liveConnections(signal) == 1, `toujours une écoute ({liveConnections(signal)}, {how})`)
end
-- Piège retiré pour de bon (boutique vendue) : plus aucune écoute.
trap:Destroy()
advance(0.1)
check(liveConnections(signal) == 0, `piège détruit : plus d'écoute ({liveConnections(signal)})`)
noErrors("trap")
summary("trap")

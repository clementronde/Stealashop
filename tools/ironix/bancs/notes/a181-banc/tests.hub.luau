-- Scénario hub (a181, vague 56) : vrai HubController sur le faux d'a160. L-165 : Label.TextColor3 = LabelColor du
-- LabelPoint (parent du billboard, ancêtre ou Adornee) ; sans l'attribut, la couleur de Clément reste. L-169 Q2 :
-- InviteFriend = « INVITE A FRIEND » seul.
local Hub, HubZone = realHub()
local function folder(map) return { WaitForChild = function(_, n) return map[n] end } end
local controllers = folder({ RewardsController = { Open = function() end }, InviteController = { Prompt = function() end } })
local Find = { path = function(root, p) return root:FindFirstChild(p, true) end }
local Shared = folder({ Config = folder({ Hub = Hub }), HubZone = HubZone, Contract = folder({ Find = Find }) })
local Workspace = inst("Workspace", "Workspace")
Workspace.DescendantAdded = signal()
local CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return signal() end }
local RunService = { RenderStepped = signal(), Heartbeat = signal(), IsStudio = function() return false end }
local services = { Players = { LocalPlayer = inst("Player", "Me") }, Workspace = Workspace, CollectionService = CollectionService,
	RunService = RunService, ReplicatedStorage = folder({ Shared = Shared }) }

local COLOR = { __color3 = true, hex = "f23f39" }
local YELLOW = { __color3 = true, hex = "ffd23a" }
local function billboard(holder, key)
	local bb = parent(inst("BillboardGui", "BB_ZoneLabel"), holder)
	local label = parent(inst("TextLabel", "Label"), bb)
	label.TextColor3 = YELLOW
	bb:SetAttribute("LabelKey", key)
	return bb, label
end
local stall = parent(inst("Model", "ENV_Hub_WeaponStall"), Workspace)
local point = parent(inst("Attachment", "LabelPoint"), stall)
point:SetAttribute("LabelColor", COLOR)
local _, onPoint = billboard(point, "WeaponShop") -- billboard dans le LabelPoint
local wheel = parent(inst("Model", "ENV_Hub_Wheel"), Workspace)
local _, noColor = billboard(wheel, "Wheel") -- pas d'attribut
local noob = parent(inst("Model", "ENV_Hub_InviteNoob"), Workspace)
local zone = parent(inst("Part", "Zone"), noob)
local noobPoint = parent(inst("Attachment", "LabelPoint"), zone)
noobPoint:SetAttribute("LabelColor", { __color3 = true, hex = "46d2ff" })
local adorned, viaAdornee = billboard(noob, "InviteFriend") -- billboard ailleurs, Adornee = LabelPoint
adorned.Adornee = noobPoint
local bad = parent(inst("Model", "ENV_Hub_Bad"), Workspace)
bad:SetAttribute("LabelColor", "rouge")
local _, badColor = billboard(bad, "PawnShop")

local HubController = load("client/Controllers/HubController.luau", {
	game = { GetService = function(_, n) return services[n] end },
	script = { Parent = controllers },
	require = function(m) return m end,
	warn = function() end,
	workspace = Workspace,
	typeof = function(v) return if type(v) == "table" and v.__color3 then "Color3" else type(v) end,
})
HubController.Start()

check(onPoint.Text == "WEAPONS" and onPoint.TextColor3 == COLOR, "C1 LabelColor du LabelPoint parent posé sur Label.TextColor3")
check(noColor.Text == "SPIN THE WHEEL" and noColor.TextColor3 == YELLOW, "C2 sans LabelColor : couleur de Clément gardée")
check(viaAdornee.TextColor3.hex == "46d2ff", "C3 LabelColor lu sur l'Adornee du billboard")
check(badColor.TextColor3 == YELLOW, "C4 LabelColor qui n'est pas un Color3 : ignoré")
check(viaAdornee.Text == "INVITE A FRIEND", `C5 noob : « INVITE A FRIEND » seul ({viaAdornee.Text})`)
check(HubZone.labelText("InviteFriend") == "INVITE A FRIEND", "C6 Config/Hub.Labels.InviteFriend")
print(`{checks} vérification(s), {fails} échec(s)`)

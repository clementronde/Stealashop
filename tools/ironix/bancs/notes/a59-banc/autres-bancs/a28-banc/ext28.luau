---------------------------------------------------------------- a28 : compléments des bouchons
-- Ajouts à la copie des bouchons d'a25 (stubs.luau + ext.luau), pour TutorialService et
-- TutorialController (DEV-046) :
--   - AnalyticsService : LogOnboardingFunnelStepEvent enregistré dans FUNNEL_LOG ; FUNNEL_FAILS = true
--     le fait échouer (comme Roblox en Studio) ;
--   - Workspace:GetServerTimeNow() (heure serveur décalée de os.clock, comme a21) ;
--   - côté « prod » : le jeu du serveur, mais RunService:IsStudio() = false (comme a21) ;
--   - UI et flèche : ScreenGui, Frame, TextLabel et TextButton (AnchorPoint, couleurs, Font,
--     événement Activated), UIAspectRatioConstraint, UISizeConstraint, Tool, Part.Shape,
--     Humanoid.HipHeight.

FUNNEL_LOG = {}
FUNNEL_FAILS = false
AnalyticsStub = {
	LogOnboardingFunnelStepEvent = function(_self, player, stepIndex, stepName, _fields)
		if FUNNEL_FAILS then
			error("Events can't be sent from Studio")
		end
		table.insert(FUNNEL_LOG, { player = player, step = stepIndex, name = stepName })
	end,
}

local function extendGame(base, extra)
	return {
		GetService = function(_self, name)
			local found = extra[name]
			if found ~= nil then
				return found
			end
			return base:GetService(name)
		end,
	}
end
games.server = extendGame(games.server, { AnalyticsService = AnalyticsStub })
do
	local prodRun = {}
	for key, value in games.server:GetService("RunService") do
		prodRun[key] = value
	end
	prodRun.IsStudio = function()
		return false
	end
	games.prod = extendGame(games.server, { RunService = prodRun })
	caches.prod = {}
end
CACHES = caches

SERVER_TIME_OFFSET = 1000 -- l'heure serveur n'est pas os.clock()
function Methods.GetServerTimeNow(_self)
	return now() + SERVER_TIME_OFFSET
end

do
	local function withDefaults(baseFn, extra)
		return function()
			local t = if baseFn then baseFn() else {}
			for key, value in extra do
				if t[key] == nil then
					t[key] = value
				end
			end
			return t
		end
	end
	local GUI_EXTRA = {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 1,
		ZIndex = 1,
		Active = false,
	}
	local TEXT_EXTRA = table.clone(GUI_EXTRA)
	TEXT_EXTRA.Font = "Enum.Font.SourceSans"
	PROPS.Frame = withDefaults(PROPS.Frame, GUI_EXTRA)
	PROPS.TextLabel = withDefaults(PROPS.TextLabel, TEXT_EXTRA)
	PROPS.TextButton = withDefaults(PROPS.TextButton, TEXT_EXTRA)
	PROPS.ScreenGui = function()
		return { Enabled = true, ResetOnSpawn = true, DisplayOrder = 0, IgnoreGuiInset = false }
	end
	PROPS.UIAspectRatioConstraint = function()
		return { AspectRatio = 1 }
	end
	PROPS.UISizeConstraint = function()
		return { MinSize = Vector2.new(0, 0), MaxSize = Vector2.new(math.huge, math.huge) }
	end
	PROPS.Tool = function()
		return { RequiresHandle = true, Enabled = true }
	end
	PROPS.PlayerGui = function()
		return {}
	end
	PROPS.Part = withDefaults(PROPS.Part, { Shape = "Enum.PartType.Block" })
	PROPS.Humanoid = withDefaults(PROPS.Humanoid, { HipHeight = 2, WalkSpeed = 16 })
	ISA.Tool = { "BackpackItem" }
	ISA.UIAspectRatioConstraint = { "UIConstraint" }
	ISA.UISizeConstraint = { "UIConstraint" }
	EVENTS.Activated = true
end

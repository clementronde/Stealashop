--!nocheck
-- Ajout d'a46 au faux Roblox d'a40 : UserInputService (UnboxController : appui court pour passer le
-- rouleau), côté client, comme le UserInputServiceStub d'a23.
UserInputServiceStub = { InputBegan = newSignal(), InputEnded = newSignal(), TouchEnabled = false, KeyboardEnabled = true }
do
	local function wrap(base)
		return {
			GetService = function(_self, name)
				if name == "UserInputService" then
					return UserInputServiceStub
				end
				return base:GetService(name)
			end,
			IsLoaded = function()
				return true
			end,
			Loaded = base.Loaded,
		}
	end
	games.client = wrap(games.client)
end

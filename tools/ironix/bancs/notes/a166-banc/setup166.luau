--!nocheck
-- Mise en place du banc a166 (coffre hebdomadaire), après setup51 et setup53 (harnais a53, copie a150).
function claimWeekly(player)
	advance(0.6) -- ClaimWeekly : 2 appels par seconde au plus (Net)
	fireAs(player, "ClaimWeekly")
	flush()
end
function weeklyOn(on)
	Workspace:SetAttribute("WeeklyChestTest", if on then true else nil)
	advance(1.1) -- un compte du service (Rewards.Tick = 1 s)
end
-- Éléments facultatifs proposés à Clément, ajoutés au faux UI_Rewards de buildUi (avant startClient).
function buildWeekly()
	local window = UI.screen:FindFirstChild("Window", true)
	local chest = make("Frame", { Name = "WeeklyChest", Visible = true }, window)
	local progress = make("TextLabel", { Name = "Progress", Text = "0/5" }, chest)
	local weekDays = make("Frame", { Name = "WeekDays" }, chest)
	local dones = {}
	for d = 1, 5 do
		local f = make("Frame", { Name = `Day{d}` }, weekDays)
		dones[d] = make("ImageLabel", { Name = "Done", Visible = false }, f)
	end
	local button = make("TextButton", { Name = "WeeklyClaimButton", Text = "" }, chest)
	local label = make("TextLabel", { Name = "ClaimLabel", Text = "OPEN" }, button)
	UI.weekly = { chest = chest, progress = progress, dones = dones, button = button, label = label }
	return UI.weekly
end

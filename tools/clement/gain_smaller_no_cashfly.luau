--[[
	Retour de Clément en Play (2026-11-11) sur le ramassage d'argent : plus de case carrée qui vole
	(UI_HUD.CashFly.Template). Seul reste le « +$… » au-dessus du joueur (BB_Gain), en plus petit.
	À lancer en Edit (barre de commande ou MCP). Annulable (Ctrl+Z).
	- BB_Gain : 60 % de sa taille d'avant ({4,5 ; 70}, {1,2 ; 20} → {2,7 ; 42}, {0,72 ; 12}).
	- CashFly.Template : supprimé. CashFly.CounterPop reste en place, mais le code ne le montre plus.
	Attention : feel2_build.luau et gain_proto.luau recréent la case s'ils sont relancés.
]]

local CH = game:GetService("ChangeHistoryService")
local rec = CH:TryBeginRecording("BB_Gain plus petit, case CashFly retiree")

local bb = game.ReplicatedStorage.Assets.UI.BB_Gain
bb.Size = UDim2.new(2.7, 42, 0.72, 12)

local fly = game.StarterGui.UI_HUD:FindFirstChild("CashFly")
local tpl = fly and fly:FindFirstChild("Template")
if tpl then tpl:Destroy() end

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "BB_Gain " .. tostring(bb.Size) .. " ; Template " .. (fly and fly:FindFirstChild("Template") and "encore là" or "retiré")

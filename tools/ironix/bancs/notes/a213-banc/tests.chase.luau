---------------------------------------------------------------- scénario « chase » : fusion58 (Cantin) : le tapis est en zone safe, la poursuite ne coupe plus le vol du tapis
local hud = startBanc(10, nil)
local Chase = requireModule(CHASE_MODULE, "client")
print("\n== C1. Poursuite en cours : le gain du tapis vole quand même (plus de repli « poursuite » au tapis)")
Chase.chased = true
P1:SetAttribute("TrainingMachine", "Treadmill")
credit(12)
check(#flyers(hud) == 1 and #childrenNamed(PLAYER_GUI, "BB_Gain") == 0, "C1a le gain vole, aucun BB_Gain sur place")
step(1.3)
check(speedText(hud) == "12" and #SPEED_POPS == 1, `C1b arrivé : nombre à jour et une pulsation ({speedText(hud)})`)
Chase.chased = false
summary()

--!nocheck
-- N. TOOL_Batte pas livré : batte en poignée grise V0, toujours en slot 2, une seule ligne en Studio.

local Tool = serverModule("ToolService")
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(60, 3, 0))
flush()
local list = A.Backpack:GetChildren()
check(#list == 2 and list[1]:GetAttribute("ToolId") == "Fists" and list[2]:GetAttribute("BatTool") == true, "N1 outil de casse puis batte")
local bat = list[2]
local handle = bat:FindFirstChild("Handle")
check(handle ~= nil and handle:IsA("Part") and bat.RequiresHandle == true and bat.Name == "Bat", "N2 batte V0 : une poignée grise")
check(logCount("TOOL_Batte pas trouvé", "PRINT", "server") == 1, "N3 une ligne dans la sortie")
spawnCharacter(A, Vector3.new(60, 3, 0))
flush()
check(logCount("TOOL_Batte pas trouvé", "PRINT", "server") == 1, "N4 pas répétée à la réapparition")
check(batOf(A) ~= nil and Tool.IsHoldingBat(A) == false, "N5 batte redonnée, pas en main")
equipBat(A)
check(Tool.IsHoldingBat(A), "N6 en main : IsHoldingBat")

summary("scénario nobat")

---------------------------------------------------------------- X (a409) classement ajouté par AddBoard
odsBroken = false
storeName = "PlayerData"
table.clear(playerList)
table.clear(tagged)
local SX = freshService()
SX.Init()
local xa = newPlayer("Xa", 501)
loadProfile(xa, { Lifetime = {}, Stats = { Speed = 1 } })
xa:SetAttribute("Income", 1000)
check(type(SX.RecordIncome) == "function" and SX.RecordIncome(xa) == 1000, "X1 RecordIncome : revenu du record")
local extraRows = {}
for i = 1, 30 do
	table.insert(extraRows, { UserId = 600 + i, Value = 31 - i, Rank = i })
end
SX.AddBoard("WeeklySteals", { Title = "Steals this week", Rows = function() return extraRows end, Text = function(v) return "S" .. v end, MaxRows = 100 })
local _, gx, lx = board("WeeklySteals")
-- panneau à ScrollingFrame : toutes les lignes (MaxRows)
local scrollModel = new("Model", { Name = "Scroll" })
scrollModel:SetAttribute("Stat", "WeeklySteals")
local sp = new("Part", { Name = "Screen" }, scrollModel)
local sg = new("SurfaceGui", { Name = "Board" }, sp)
new("TextLabel", { Name = "Title", Text = "" }, sg)
local sl = new("ScrollingFrame", { Name = "List" }, sg)
local stpl = new("Frame", { Name = "Template", Visible = false }, sl)
new("TextLabel", { Name = "Rank" }, stpl)
new("ImageLabel", { Name = "Avatar" }, stpl)
new("TextLabel", { Name = "PlayerName" }, stpl)
new("TextLabel", { Name = "Value" }, stpl)
table.insert(tagged.Leaderboard, scrollModel)
local okx = pcall(SX.Step, 0)
local rx = rowsOf(lx)
check(okx and gx.Title.Text == "Steals this week", `X2 Title du classement ajouté ({gx.Title.Text})`)
check(#rx == LB.Rows and rx[1].Rank.Text == "#1" and rx[1].Value.Text == "S30", `X3 List simple : {LB.Rows} lignes, texte du service ({#rx}, {rx[1] and rx[1].Value.Text})`)
check(#rowsOf(sl) == 30, `X4 ScrollingFrame : jusqu'à MaxRows lignes ({#rowsOf(sl)})`)
local _, gi, li = board("Income")
pcall(SX.Step, 10 * LB.ReadInterval)
check(gi.Title.Text == "Most money/s" and #rowsOf(li) >= 1 and string.find(rowsOf(li)[1].Value.Text, "/s", 1, true) ~= nil, "X5 panneaux Income inchangés à côté (titre et texte $/s)")

---------------------------------------------------------------- F (a430, L-330) : copies de ServerStorage/MapBackups ignorées
local storage = new("Folder", { Name = "ServerStorage" })
local backup, gbk, lbk = board("WeeklySteals")
backup.Parent = storage
pcall(SX.Step, 20 * LB.ReadInterval)
check(#rowsOf(lbk) == 0 and gbk.Title.Text == "", "F1 panneau sous ServerStorage (sauvegarde) : rien d écrit")
check(#rowsOf(lx) == LB.Rows and #rowsOf(sl) == 30, "F2 panneaux du Workspace toujours remplis")

print(`{checks} vérification(s), {fails} échec(s)`)

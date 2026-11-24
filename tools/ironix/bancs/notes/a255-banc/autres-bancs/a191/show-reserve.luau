--!nocheck
-- a242 (vague 72) : scénarios d'avant la vague 72 : la réserve montrée dans UI_Displayed (Config/Displayed.ShowReserve).
SOURCES["shared/Config/Displayed.luau"] = string.gsub(SOURCES["shared/Config/Displayed.luau"], "ShowReserve = false", "ShowReserve = true")

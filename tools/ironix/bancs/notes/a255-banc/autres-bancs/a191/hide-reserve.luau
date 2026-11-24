--!nocheck
-- a255 (vague 73) : le scénario a242 (réserve hors de l'écran) tourne avec Config/Displayed.ShowReserve forcé à false.
SOURCES["shared/Config/Displayed.luau"] = string.gsub(SOURCES["shared/Config/Displayed.luau"], "ShowReserve = true", "ShowReserve = false")

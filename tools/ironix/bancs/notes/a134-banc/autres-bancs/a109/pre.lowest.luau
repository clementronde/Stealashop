--!nocheck
-- Scénario lowest : ShelfOpen.LuckBoost = "AboveLowest" (l'autre mode de la règle).
SOURCES["shared/Config/ShelfOpen.luau"] = (string.gsub(SOURCES["shared/Config/ShelfOpen.luau"], 'LuckBoost = "AboveBox"', 'LuckBoost = "AboveLowest"'))
assert(string.find(SOURCES["shared/Config/ShelfOpen.luau"], 'LuckBoost = "AboveLowest"', 1, true), "pre.lowest : LuckBoost introuvable")

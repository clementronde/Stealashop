--!nocheck
-- Scénario oldflow : Features.ShelfOpen forcé à false (ancien déroulé).
SOURCES["shared/Config/Features.luau"] = (string.gsub(SOURCES["shared/Config/Features.luau"], "ShelfOpen = true", "ShelfOpen = false"))

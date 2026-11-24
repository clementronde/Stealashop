--!nocheck
-- a202 : Features.SingleBoxReveal = false (l'ouverture d'avant).
SOURCES["shared/Config/Features.luau"] = string.gsub(SOURCES["shared/Config/Features.luau"], "SingleBoxReveal = true", "SingleBoxReveal = false")

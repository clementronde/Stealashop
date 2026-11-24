--!nocheck
-- Interrupteur Config/Features.TruckEvent coupé.
local features = SOURCES["shared/Config/Features.luau"]
local patched, n = string.gsub(features, "TruckEvent = true", "TruckEvent = false")
assert(n == 1, "pre.off : interrupteur TruckEvent introuvable dans Config/Features")
SOURCES["shared/Config/Features.luau"] = patched

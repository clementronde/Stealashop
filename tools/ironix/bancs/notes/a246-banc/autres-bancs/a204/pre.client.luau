--!nocheck
-- a204 : RevealController seul ; Reveal/Logic, Reveal/Ceiling, bouchons ShatterController et UiFeelController posés
-- par head.client.luau. REVEAL_OFF (scénario « off ») : Features.SingleBoxReveal = false.
CLIENT_LIST = { "RevealController" }
if REVEAL_OFF then
	local key = "shared/Config/Features.luau"
	local text, n = string.gsub(SOURCES[key], "SingleBoxReveal = true", "SingleBoxReveal = false")
	assert(n == 1, "SingleBoxReveal introuvable dans Features")
	SOURCES[key] = text
end

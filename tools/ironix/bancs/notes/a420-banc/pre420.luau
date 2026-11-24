-- a420 : après pre416.luau. Scénario « …sans » : Chase.ClientView.Contact.Enabled coupé (la règle d'a416 telle quelle,
-- mesure « avant »). Sans le bloc Contact (arbre d'avant a420) : rien à couper.
do
	local name = A193_SCENARIO
	if string.sub(name, -4) == "sans" and string.find(SOURCES["shared/Config/Chase.luau"], "Contact = {", 1, true) then
		patch("shared/Config/Chase.luau", "(Contact = {[^\n]*\n%s*Enabled = )true,", "%1false,")
	end
end

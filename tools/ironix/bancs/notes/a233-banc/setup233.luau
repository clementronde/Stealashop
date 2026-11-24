---------------------------------------------------------------- montage a233 (après setup232.luau du banc a232)
-- Faux Roblox (ajouts purs, ce banc seulement), comme le modèle de Clément vu en Play le 17/11 :
--   - BB_Gain.Row.Amount en Montserrat Heavy par FontFace : Font vaut Enum.Font.Unknown (GetTextSize impossible) ;
--   - police aux chiffres larges : MEASURE = 0,75 em par chiffre, 0,6 pour « + », 0,25 pour une espace (insécable ou
--     non), 0,3 pour « | », 0,55 sinon (TextBounds des TextLabel et checkLine la lisent) ;
--   - TextService:GetTextBoundsAsync(params) : attend une image (comme Roblox, il attend), compte ses appels, exige
--     params.Font = la FontFace Heavy, renvoie (MEASURE × Size, Size).
HEAVY = { Family = "rbxasset://fonts/families/Montserrat.json", Weight = "Enum.FontWeight.Heavy", Style = "Enum.FontStyle.Normal" }
PROPS.GetTextBoundsParams = { Text = "", Font = HEAVY, Size = 0, Width = 0, RichText = false }
function MEASURE(text)
	local em = 0
	for _, code in utf8.codes(PLAIN(text)) do
		em += if code >= 48 and code <= 57 then 0.75
			elseif code == 43 then 0.6
			elseif code == 32 then 0.25
			elseif code == 124 then 0.3
			else 0.55
	end
	return em
end
BOUNDS_CALLS = 0
BOUNDS_MODE = "ok" -- "ok" | "error" (GetTextBoundsAsync lève une erreur)
TEXT_SERVICE.GetTextBoundsAsync = function(_, params)
	BOUNDS_CALLS += 1
	taskLib.wait()
	if BOUNDS_MODE == "error" then
		error("TextService: font not loaded")
	end
	assert(params.Font == HEAVY, "GetTextBoundsAsync sans la FontFace du modèle")
	return Vector2.new(MEASURE(params.Text) * params.Size, params.Size)
end
do
	local amount = el(el(BB_GAIN, "Row"), "Amount")
	amount.FontFace = HEAVY
	amount.Font = "Enum.Font.Unknown"
end

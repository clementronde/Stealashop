--!strict
-- GainFit (a507, L-476, Clément 27/11 sur le tapis : « Ça doit être assez collé, et responsive en fonction du nombre
-- de pas ») : largeur de BB_Gain.Row.Amount mise à celle de son texte, pour que le « +N » et l'icône (Row et son
-- UIListLayout centré, de Clément) soient centrés ensemble quelle que soit la longueur du nombre. Logique pure, aucun
-- service Roblox : GainController mesure (TextService), ce module calcule. Testable hors Studio.
--
-- API :
--   GainFit.Margin   marge ajoutée à la largeur du texte (2 %, celle de la liaison L-476)
--   GainFit.TextSize(boxHeight, scaled, textSize, maxSize?) -> number
--       Taille rendue du texte : en TextScaled, la hauteur de sa case (au plus 100, au plus maxSize, celui d'un
--       UITextSizeConstraint) ; sinon textSize.
--   GainFit.WidthScale(rowWidth, boxHeight, widthAt100, scaled, textSize, maxSize?, maxScale) -> number?
--       Largeur d'Amount en Scale de Row : largeur du texte à sa taille rendue (widthAt100 = largeur à la taille 100),
--       plus Margin, divisée par la largeur de Row ; jamais plus large que maxScale (la largeur de Clément : un texte
--       long garde sa case et rétrécit comme avant). nil si une mesure manque (pas encore à l'écran) : rien à changer.

local GainFit = {}

GainFit.Margin = 0.02

local function valid(value: number): boolean
	return value == value and value > 0 and value < math.huge
end

function GainFit.TextSize(boxHeight: number, scaled: boolean, textSize: number, maxSize: number?): number
	if not scaled then
		return textSize
	end
	local size = math.min(boxHeight, 100)
	if maxSize ~= nil and valid(maxSize) then
		size = math.min(size, maxSize)
	end
	return size
end

function GainFit.WidthScale(
	rowWidth: number,
	boxHeight: number,
	widthAt100: number,
	scaled: boolean,
	textSize: number,
	maxSize: number?,
	maxScale: number
): number?
	if not (valid(rowWidth) and valid(boxHeight) and valid(widthAt100) and valid(maxScale)) then
		return nil
	end
	local size = GainFit.TextSize(boxHeight, scaled, textSize, maxSize)
	if not valid(size) then
		return nil
	end
	local need = widthAt100 * size / 100 * (1 + GainFit.Margin)
	return math.min(need / rowWidth, maxScale)
end

table.freeze(GainFit)

return GainFit

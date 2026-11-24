---------------------------------------------------------------- ajouts a222 (vague 66, L-210 points 6 et 9)
-- Collé après ext-a189.luau : propriétés que lisent Controllers/UI/ScrollReveal (CanvasPosition, ScrollingDirection)
-- et l'ajustement du survol de Motion (AnchorPoint, UIStroke). Ajouts purs.
for _, class in { "Frame", "ImageLabel", "TextLabel", "TextButton", "ImageButton", "ScrollingFrame" } do
	PROPS[class] = PROPS[class] or {}
	if PROPS[class].AnchorPoint == nil then
		PROPS[class].AnchorPoint = Vector2.new(0, 0)
	end
end
PROPS.ScrollingFrame.CanvasPosition = PROPS.ScrollingFrame.CanvasPosition or Vector2.new(0, 0)
PROPS.ScrollingFrame.ScrollingDirection = PROPS.ScrollingFrame.ScrollingDirection or "Enum.ScrollingDirection.Y"
PROPS.UIStroke.Enabled = if PROPS.UIStroke.Enabled == nil then true else PROPS.UIStroke.Enabled
PROPS.UIStroke.Transparency = PROPS.UIStroke.Transparency or 0
PROPS.UIStroke.ApplyStrokeMode = PROPS.UIStroke.ApplyStrokeMode or "Enum.ApplyStrokeMode.Contextual"

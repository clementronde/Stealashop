--!strict
-- SignPose (client ; liaison L-082 et L-108 point 5) : règle de pose commune des panneaux plantés de
-- Clément, UpgradeSign (UpgradeController) et StoreReqSign (StoreReqSignController).
--
-- Le bas de la boîte du panneau va au point (Attachment), la face de Board (SurfaceGui Face = Front,
-- donc son LookVector) tournée comme le LookVector du point, mis à l'horizontale. Pour tourner un
-- panneau, Clément tourne son point. Sans LookVector utilisable (point vertical), `fallbackLook`, puis
-- −Z. Aucune taille ni couleur changée.
--
-- API :
--   SignPose.flat(vector) -> Vector3?          vecteur mis à l'horizontale et normé, nil s'il est vertical
--   SignPose.place(sign, board, target, fallbackLook?)   pose `sign` (PivotTo) sur `target`

local SignPose = {}

function SignPose.flat(vector: Vector3): Vector3?
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 1e-3 then horizontal.Unit else nil
end

local flat = SignPose.flat

function SignPose.place(sign: Model, board: BasePart?, target: Attachment, fallbackLook: Vector3?)
	local pivot = sign:GetPivot()
	local boxCFrame, boxSize = sign:GetBoundingBox()
	local bottom = boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)
	local boardLook = if board then flat(board.CFrame.LookVector) else nil
	local front = boardLook or flat(pivot.LookVector) or Vector3.new(0, 0, -1)
	local from = CFrame.lookAt(bottom, bottom + front)
	local world = target.WorldCFrame
	local fallback = if fallbackLook then flat(fallbackLook) else nil
	local out = flat(world.LookVector) or fallback or Vector3.new(0, 0, -1)
	local to = CFrame.lookAt(world.Position, world.Position + out)
	sign:PivotTo(to * from:Inverse() * pivot)
end

return SignPose

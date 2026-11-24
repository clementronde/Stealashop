---------------------------------------------------------------- a32 : compléments du faux Roblox (alerte de la victime, DEV-042)
-- Ajouts au faux d'a30 (stubs.luau) et aux compléments d'a29 (ext29.luau), pour TheftAlertController :
--   - Sound : Play et Stop (IsPlaying), signal Ended (déclenché par le banc seulement, endSound) ;
--     chaque Play et chaque Stop est noté dans SOUND_LOG ;
--   - la caméra du client : Workspace.CurrentCamera, un objet Camera dont le banc pose le CFrame.

CLASS_EVENTS.Ended = true
SOUND_LOG = {}
function Methods.Play(self)
	rawget(self, "_props").IsPlaying = true
	table.insert(SOUND_LOG, { t = now(), action = "Play", name = rawget(self, "_props").Name, sound = self })
end
function Methods.Stop(self)
	rawget(self, "_props").IsPlaying = false
	table.insert(SOUND_LOG, { t = now(), action = "Stop", name = rawget(self, "_props").Name, sound = self })
end
-- Fin naturelle d'un son (Sound.Ended).
function endSound(sound)
	rawget(sound, "_props").IsPlaying = false
	sound.Ended:Fire(sound.SoundId)
end
function soundCount(action, name)
	local n = 0
	for _, e in SOUND_LOG do
		if e.action == action and (name == nil or e.name == name) then
			n += 1
		end
	end
	return n
end

CAMERA = make("Camera", { Name = "Camera", CFrame = CFrame.new(0, 10, 0) }, Workspace)
Workspace.CurrentCamera = CAMERA

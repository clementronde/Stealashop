--!nocheck
-- a171, banc a30 : StoreHeistService.OnBoxGrabbed (prise d'un colis fermé) n'existe plus depuis a158 ; le banc écoutait la prise
-- pour savoir qui portait quel payload. a171OnGrabbed garde ces écouteurs et grabShelf (aide prise-directe d'a158) les appelle.
A171_GRAB_LISTENERS = {}
function a171OnGrabbed(fn)
	table.insert(A171_GRAB_LISTENERS, fn)
	return function() end
end
local a171GrabShelf = grabShelf
function grabShelf(player, store, slotNumber)
	local ok = a171GrabShelf(player, store, slotNumber)
	if ok then
		local payload = serverModule("CarryService").GetPayload(player)
		for _, fn in A171_GRAB_LISTENERS do
			fn(player, payload)
		end
	end
	return ok
end

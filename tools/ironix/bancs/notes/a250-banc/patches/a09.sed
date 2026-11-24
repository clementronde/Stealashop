# a250b : les 7 Unbox_* de L-237 entrent au contrat (23 animations du joueur), marqueur Impact, pas encore jouées par le
# code : aucun son au registre MarkerSounds tant que L-236 ne les joue pas.
s/"4\/16 animation\(s\) préchargée\(s\)"/"4\/23 animation(s) préchargée(s)"/
s/if spec\.Marker and spec\.Name ~= "BenchLift" then/if spec.Marker and spec.Name ~= "BenchLift" and string.sub(spec.Name, 1, 6) ~= "Unbox_" then/

# a229 (vague 69) : les vigiles de nuit sont posés un par image (GuardService.StartNightPatrol). Pour les bancs
# d'avant, qui vérifient leur look, leur place, leur ronde ou les potions juste après la tombée de la nuit : pose
# d'un coup, comme avant (le rythme est vérifié par le banc a229).
/for index, plan in plans do/{n;s/if index > 1 then/if false then/}

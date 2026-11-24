# a309 (22/11, Cantin : « fais la roue de la chance aussi ») : BOX et RARE BOX donnent un colis de zone (Prize ZoneBox,
# règles BestZone et NextZone de Config/Rewards.ZoneBox), ouvert par la scène quand la roue s'arrête : Result vide
# (WheelResult(2, "")), événement WheelSpin « Gift - ZoneBox », secteur 6 = règle NextZone (avant : Box Rank 2).
s/string\.find\(wr\[1\]\.args\[2\], "Item", 1, true\), `WheelResult\(2, « \{wr\[1\] and wr\[1\]\.args\[2\]\} »\)`/wr[1].args[2] == "", `WheelResult(2, « {wr[1] and wr[1].args[2]} ») : Result vide, l'objet est dit par la scène (a309)`/
s/Wheel\.Sectors\[6\]\.Prize\.Rank == 2, `roue : colis de la plus basse rareté/Wheel.Sectors[6].Prize.Kind == "ZoneBox" and Wheel.Sectors[6].Prize.Rule == "NextZone" and Wheel.Sectors[2].Prize.Rule == "BestZone", `roue (a309 : colis de zone, BestZone et NextZone) : zone 1, une seule rareté/
s/ws\[1\]\.fields\[2\] == "Gift - Box" and ws\[1\]\.fields\[3\] == "Spin - Free"/ws[1].fields[2] == "Gift - ZoneBox" and ws[1].fields[3] == "Spin - Free"/

# a262 (vague 76, 2026-11-19) : banc a14 (boutique, revenus exposés). Revenus de la vague 76 (Formulas.ItemIncome(objet)) :
# le smartphone (Peu commun) laisse sa place à la Console de salon (Rare de zone 3, 60 $/s), la Peluche géante (Peu commune)
# au Sarcophage (Légendaire de zone 5, 3 500 $/s), le Yo-yo (Commun) au Skateboard (Peu commun de zone 2, 8 $/s), le paquet
# de chips (1,331 $/s) à la Canette (1 $/s) ; Pot de nouilles 60 $/s ; Secret 150 000 $/s, zone ou pas (plus d'avertissement) ;
# Figurine holographique Peu commune 15,59 $/s ; Lingot d'or Rare de zone 6, 105 $/s.
return unless has(q{== 1. Installation de la boutique sauvegardée});
lit(q{give(data, "Z3_Smartphone")}, q{give(data, "Z3_ConsoleDeSalon")}, 'phone');
lit(q{give(data, "Z2_PelucheGeante")}, q{give(data, "Z5_Sarcophage")}, 'ticket');
lit(q{give(data, "Z2_YoYo")}, q{give(data, "Z2_Skateboard")}, 'yoyo');
lit(q{give(data, "Z1_PaquetDeChips")}, q{give(data, "Z1_CanetteDeSoda")}, 'chips');
lit(q{alice:GetAttribute("Income") == 301,}, q{alice:GetAttribute("Income") == 61,}, '301');
lit(q{DisplayService.GetIncome(alice) == 301,}, q{DisplayService.GetIncome(alice) == 61,}, 'GetIncome 301');
lit(q{revenu $301/s"}, q{revenu $61/s"}, 'message 301');
lit(q{label(phoneModel, "Income").Text == "+$300/s"}, q{label(phoneModel, "Income").Text == "+$60/s"}, 'billboard 300');
lit(q{register >= 301 * 9 - 1 and register <= 3010}, q{register >= 61 * 9 - 1 and register <= 610}, 'register');
lit(q{if gain < 300 or gain > 302 then}, q{if gain < 60 or gain > 62 then}, 'gain');
lit(q{near(DisplayService.GetRegister(alice), 3010, 1)}, q{near(DisplayService.GetRegister(alice), 610, 1)}, 'GetRegister');
lit(q{v2 ~= nil and v2 >= 2600 and v2 <= 3010}, q{v2 ~= nil and v2 >= 520 and v2 <= 610}, 'v2');
lit(q{first.amount >= 3000 and first.amount <= 3100}, q{first.amount >= 600 and first.amount <= 620}, 'amount');
lit(q{v2b ~= nil and v2b >= 300 and v2b <= 700}, q{v2b ~= nil and v2b >= 60 and v2b <= 140}, 'v2b');
lit(q{alice:GetAttribute("Income") == 317,}, q{alice:GetAttribute("Income") == 69,}, '317');
lit(q{alice:GetAttribute("Income") == 318,}, q{alice:GetAttribute("Income") == 70,}, '318');
lit(q{alice:GetAttribute("Income") == 323,}, q{alice:GetAttribute("Income") == 130,}, '323', 1);
lit(q{alice:GetAttribute("Income") == before - 300,}, q{alice:GetAttribute("Income") == before - 60,}, '-300');
lit(q{alice:GetAttribute("Income") == before - 16,}, q{alice:GetAttribute("Income") == before - 8,}, '-16');
lit(q{secretModel:GetAttribute("Income") == 1000 and logHas("sans zone : revenu calculé en zone 1", "WARN")}, q{secretModel:GetAttribute("Income") == 150000}, 'secret');
lit(q{label(secretModel, "Income").Text == "+$1K/s"}, q{label(secretModel, "Income").Text == "+$150K/s"}, 'secret bb');
lit(q{GetAttribute("Income") == 25000000,}, q{GetAttribute("Income") == 150000,}, 'secret6');
lit(q{label(item(plot1, secret6Slot), "Income").Text == "+$25M/s"}, q{label(item(plot1, secret6Slot), "Income").Text == "+$150K/s"}, 'secret6 bb');
lit(q{item(plot1, ticketSlot):GetAttribute("Income") == 400,}, q{item(plot1, ticketSlot):GetAttribute("Income") == 3500,}, 'ticket');
lit(q{ItemIncome(zone, def.Rarity)}, q{ItemIncome(def.Id)}, 'somme');
lit(q{label(hotModel, "Income").Text == "+$1.6K/s"}, q{label(hotModel, "Income").Text == "+$15.5/s"}, 'hot');
lit(q{label(hotModel, "Rarity").Text == "MYTHIC" and label(hotModel, "Rarity").TextColor3 == rarityColor("Mythic")}, q{label(hotModel, "Rarity").Text == "UNCOMMON" and label(hotModel, "Rarity").TextColor3 == rarityColor("Uncommon")}, 'hot rareté');
lit(q{bob:GetAttribute("Income") == 25000 and label(item(plot1, 2), "Income").Text == "+$25K/s"}, q{bob:GetAttribute("Income") == 105 and label(item(plot1, 2), "Income").Text == "+$105/s"}, 'bob');
lit(q{cashOuts[#cashOuts].amount >= 24000,}, q{cashOuts[#cashOuts].amount >= 100,}, 'caisse de Bob');

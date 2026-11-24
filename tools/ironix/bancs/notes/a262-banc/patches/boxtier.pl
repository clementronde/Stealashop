# a262 : un faux colis du banc qui reçoit un Tier reçoit aussi la BoxRarity au même temps de prise (Standard : Commun
# 0,3 s ; Premium : Rare 0,6 s ; Luxe : Légendaire 1 s), lue par le client depuis la vague 76 (invite, maintien).
unless (has('A262_SETTIER = function')) {
	$t =~ s/\b([A-Za-z_][A-Za-z_0-9]*):SetAttribute\("Tier", ([^()\n]+?)\)/A262_SETTIER($1, $2)/g;
	$t = "A262_BOXRARITY = { Standard = \"Common\", Premium = \"Rare\", Luxe = \"Legendary\" }\nA262_SETTIER = function(m: any, tier: any)\n\tm:SetAttribute(\"Tier\", tier)\n\tif m:GetAttribute(\"BoxRarity\") == nil and A262_BOXRARITY[tier] ~= nil then\n\t\tm:SetAttribute(\"BoxRarity\", A262_BOXRARITY[tier])\n\tend\nend\n" . $t;
}

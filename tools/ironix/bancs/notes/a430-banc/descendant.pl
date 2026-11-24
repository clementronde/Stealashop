#!/usr/bin/perl
# a430 (L-330) : LeaderboardService ne garde que les panneaux du Workspace (board:IsDescendantOf(Workspace)). Le faux
# Roblox du banc a161 (server.luau, repris par a409) n'a pas IsDescendantOf : ajout pur, avant Inst.IsA. Un panneau sans
# parent compte comme posé dans le Workspace (comme avant) ; sous un ancêtre nommé ServerStorage : non.
# Fichier sans ce faux (autres scénarios) : inchangé.
use strict;
my $f = shift;
open(my $in, "<:raw", $f) or die "lecture $f";
local $/; my $t = <$in>; close $in;
exit 0 unless $t =~ /local function freshService\(\)/ && $t =~ /\nfunction Inst\.IsA\(self, class\)/ && $t !~ /function Inst\.IsDescendantOf/;
my $add = <<'LUA';
function Inst.IsDescendantOf(self, other) -- a430 : faux Instance:IsDescendantOf (sans parent = dans le Workspace)
	local p = self.Parent
	while p ~= nil do
		if p == other then
			return true
		end
		if p.Name == "ServerStorage" then
			return false
		end
		p = p.Parent
	end
	return true
end
LUA
$t =~ s/\nfunction Inst\.IsA\(self, class\)/\n${add}function Inst.IsA(self, class)/ or die "pas de Inst.IsA";
open(my $out, ">:raw", $f) or die "écriture $f"; print $out $t; close $out;

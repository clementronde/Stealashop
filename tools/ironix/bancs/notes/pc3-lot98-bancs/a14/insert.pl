#!/usr/bin/perl
# lot98 (petit chef 3) : insère scale.luau dans le fichier assemblé du banc a14, juste avant « -- Players » (après les
# méthodes GetPivot et PivotTo du faux Roblox). Sans ce repère, ou déjà inséré : rien.
use strict;
use warnings;
my ($luau, $file) = @ARGV;
local $/;
open(my $in, '<', $file) or exit 0;
my $s = <$in>;
close $in;
exit 0 if $s =~ /_pc3Scale/ or $s !~ /\nfunction Methods\.PivotTo\(self, target\)\n/;
open(my $add, '<', $luau) or die "lecture $luau : $!";
my $code = <$add>;
close $add;
$s =~ s/\n-- Players\nfunction Methods\.GetPlayers\(self\)\n/\n$code-- Players\nfunction Methods.GetPlayers(self)\n/ or exit 0;
open(my $out, '>', $file) or die;
print $out $s;
close $out;

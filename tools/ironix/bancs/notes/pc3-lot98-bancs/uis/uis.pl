#!/usr/bin/perl
# lot98 (petit chef 3) : ajoute UserInputService = {} à la table des services du faux Roblox (makeGame, banc a39 et ses
# copies) s'il n'y est pas. a419 : Shared/Gamepad fait game:GetService("UserInputService") au chargement ; tous ses
# usages sont sous pcall, une table vide suffit. Usage : perl uis.pl <fichier .luau lancé>
use strict;
use warnings;
my ($f) = @ARGV;
local $/;
open(my $fh, '<', $f) or die "lecture $f : $!";
my $s = <$fh>;
close $fh;
exit 0 if $s =~ /^\s*UserInputService = /m;
my $n = ($s =~ s/^(\t\tContentProvider = ContentProvider,\r?\n)/$1\t\tUserInputService = {}, -- lot98 (petit chef 3) : a419, Shared\/Gamepad\n/mg);
exit 0 if $n == 0;
open(my $oh, '>', $f) or die;
print $oh $s;
close $oh;

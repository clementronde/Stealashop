# a265 (vague 79, 2e commit, 2026-11-20) : depuis a265 l'étape du maintien (phase "Begin" | "End" | "Cancel") est
# OBLIGATOIRE sur GrabItem, OpenShelfBox, StealItem, StealFloorItem et GrabDropped ; un appel sans étape est refusé.
# Les ~340 fichiers de scénarios des bancs appellent ces remotes sans étape (ancien déroulé : 1er appel = début,
# 2e = fin). Pour eux, ce correctif du fichier assemblé (posé par le faux luau.exe du lanceur, voir run-all-bancs.sh)
# joue le client : un appel de banc sans étape devient "End" si un maintien est ouvert sur la même cible, sinon
# "Begin" (exactement l'ancienne règle, qu'un vrai client envoie de lui-même), et la définition Net garde l'étape
# facultative pour laisser passer ces appels. Les cas a265 « sans étape » posent A265_ETAPE_STRICTE = true : le
# garde du vrai code refuse alors l'appel. Arbre sans le garde a265 : fichier inchangé.
#   perl etape.pl <fichier assemblé>
use strict;
my ($target) = @ARGV;
local $/;
open(my $in, '<', $target) or die "a265 etape.pl : $target illisible\n";
my $t = <$in>;
close $in;
exit 0 if index($t, "--a265-etape") >= 0;
exit 0 if index($t, "if phase == nil or not HOLD_PHASES[phase] then") < 0
	&& index($t, 'return { Name = "phase", Kind = "string", Max = 8 }') < 0;
my $before = $t;
$t =~ s/return \{ Name = "phase", Kind = "string", Max = 8 \}/return { Name = "phase", Kind = "string", Max = 8, Optional = true } -- a265 (banc)/g;
my $G = 'if phase == nil or not HOLD_PHASES\[phase\] then';
my @handlers = (
	[ 'local function onOpenShelfBox(player: Player, slotId: string, phase: string?)',
		'local h = openHolds[player]; phase = if h and h.Slot == slot and h.Target == slot.Box then "End" else "Begin"' ],
	[ 'local function onGrabItem(player: Player, slotId: string, phase: string?)',
		'local h = holds[player]; phase = if h and h.Slot == slot and slot.Item ~= nil and h.Target == slot.Item then "End" else "Begin"' ],
	[ 'local function onStealItem(player: Player, plotIndex: number, slotIndex: number, phase: string?)',
		'local h = holds[player]; phase = if h and h.Plot == plot and h.Slot == slotIndex then "End" else "Begin"' ],
	[ 'local function onStealFloorItem(player: Player, plotIndex: number, itemUid: string, phase: string?)',
		'local h = holds[player]; phase = if h and h.Plot == plot and h.Floor and h.Uid == itemUid then "End" else "Begin"' ],
	[ 'local function onGrabDropped(player: Player, dropId: string, phase: string?)',
		'local h = holds[player]; phase = if h and h.DropId == dropId then "End" else "Begin"' ],
);
for my $hd (@handlers) {
	my ($sig, $infer) = @$hd;
	my $pos = 0;
	while ((my $i = index($t, $sig, $pos)) >= 0) {
		my $g = index($t, "if phase == nil or not HOLD_PHASES[phase] then", $i);
		my $next = index($t, "\nlocal function ", $i + length($sig));
		die "a265 etape.pl : garde de l'étape introuvable après « $sig » dans $target\n"
			if $g < 0 || ($next >= 0 && $g > $next);
		my $line = "if phase == nil and A265_ETAPE_STRICTE ~= true then $infer end -- a265 (banc)\n\t";
		substr($t, $g, 0) = $line;
		$pos = $g + length($line) + 10;
	}
}
exit 0 if $t eq $before;
$t = "--a265-etape\n" . $t;
open(my $out, '>', $target) or die;
print $out $t;
close $out;

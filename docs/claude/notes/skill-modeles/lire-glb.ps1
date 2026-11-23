param([Parameter(Mandatory = $true)][string]$Path)
# Lit un .glb de Claude Design sans Blender et sans rien executer : pieces, couleurs, triangles, taille en studs.
# Usage (PowerShell, depuis ce dossier) :
#   & ([scriptblock]::Create((Get-Content -Raw -Encoding UTF8 .\lire-glb.ps1))) -Path .\tour-02\bubble-tea_3d_v1.glb
# A comparer au prompt : taille (L x H x P), base a y = 0, centre au sol en (0, 0), noms des pieces, couleurs, budget de triangles.
# Les couleurs sont converties du lineaire (glTF) vers le sRGB, pour les comparer aux codes hexa du prompt.
$ErrorActionPreference = 'Stop'

$bytes = [System.IO.File]::ReadAllBytes($Path)
$magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
if ($magic -ne 'glTF') { throw "Pas un fichier GLB ($magic)" }
$jsonLen = [BitConverter]::ToUInt32($bytes, 12)
$jsonType = [System.Text.Encoding]::ASCII.GetString($bytes, 16, 4)
if ($jsonType -ne 'JSON') { throw "Premier bloc inattendu ($jsonType)" }
$g = [System.Text.Encoding]::UTF8.GetString($bytes, 20, $jsonLen) | ConvertFrom-Json

function Get-Prop($obj, [string]$name, $default) {
    if ($null -ne $obj -and ($obj.PSObject.Properties.Name -contains $name)) { return $obj.$name }
    return $default
}

function New-Identity {
    $m = New-Object 'double[,]' 4, 4
    for ($i = 0; $i -lt 4; $i++) { $m[$i, $i] = 1.0 }
    return , $m
}

function Get-LocalMatrix($node) {
    $raw = Get-Prop $node 'matrix' $null
    $m = New-Object 'double[,]' 4, 4
    if ($null -ne $raw) {
        for ($c = 0; $c -lt 4; $c++) { for ($r = 0; $r -lt 4; $r++) { $m[$r, $c] = [double]$raw[$c * 4 + $r] } }
        return , $m
    }
    $t = Get-Prop $node 'translation' @(0, 0, 0)
    $q = Get-Prop $node 'rotation' @(0, 0, 0, 1)
    $s = Get-Prop $node 'scale' @(1, 1, 1)
    $x = [double]$q[0]; $y = [double]$q[1]; $z = [double]$q[2]; $w = [double]$q[3]
    $R = @(
        @((1 - 2 * ($y * $y + $z * $z)), (2 * ($x * $y - $z * $w)), (2 * ($x * $z + $y * $w))),
        @((2 * ($x * $y + $z * $w)), (1 - 2 * ($x * $x + $z * $z)), (2 * ($y * $z - $x * $w))),
        @((2 * ($x * $z - $y * $w)), (2 * ($y * $z + $x * $w)), (1 - 2 * ($x * $x + $y * $y)))
    )
    for ($i = 0; $i -lt 3; $i++) {
        for ($j = 0; $j -lt 3; $j++) { $m[$i, $j] = $R[$i][$j] * [double]$s[$j] }
        $m[$i, 3] = [double]$t[$i]
    }
    $m[3, 3] = 1.0
    return , $m
}

function Get-Product($A, $B) {
    $C = New-Object 'double[,]' 4, 4
    for ($i = 0; $i -lt 4; $i++) {
        for ($j = 0; $j -lt 4; $j++) {
            $sum = 0.0
            for ($k = 0; $k -lt 4; $k++) { $sum += $A[$i, $k] * $B[$k, $j] }
            $C[$i, $j] = $sum
        }
    }
    return , $C
}

function Convert-ToHex($factor) {
    $parts = foreach ($c in @($factor[0], $factor[1], $factor[2])) {
        $c = [double]$c
        if ($c -le 0.0031308) { $v = 12.92 * $c } else { $v = 1.055 * [math]::Pow($c, 1 / 2.4) - 0.055 }
        '{0:X2}' -f [int][math]::Round([math]::Max([double]0.0, [math]::Min([double]1.0, [double]$v)) * 255.0)
    }
    return '#' + ($parts -join '')
}

$state = @{
    rows  = New-Object System.Collections.Generic.List[object]
    gmin  = @([double]::MaxValue, [double]::MaxValue, [double]::MaxValue)
    gmax  = @([double]::MinValue, [double]::MinValue, [double]::MinValue)
    total = 0
}

function Invoke-Walk([int]$idx, $parent) {
    $node = $g.nodes[$idx]
    $world = Get-Product $parent (Get-LocalMatrix $node)
    $meshIdx = Get-Prop $node 'mesh' $null
    if ($null -ne $meshIdx) {
        $mesh = $g.meshes[[int]$meshIdx]
        $tri = 0
        $mats = @()
        $nmin = @([double]::MaxValue, [double]::MaxValue, [double]::MaxValue)
        $nmax = @([double]::MinValue, [double]::MinValue, [double]::MinValue)
        foreach ($prim in $mesh.primitives) {
            $mode = Get-Prop $prim 'mode' 4
            $posAcc = $g.accessors[[int]$prim.attributes.POSITION]
            $indices = Get-Prop $prim 'indices' $null
            if ($mode -eq 4) {
                if ($null -ne $indices) { $tri += [int]($g.accessors[[int]$indices].count / 3) }
                else { $tri += [int]($posAcc.count / 3) }
            }
            $matIdx = Get-Prop $prim 'material' $null
            if ($null -ne $matIdx) {
                $mat = $g.materials[[int]$matIdx]
                $pbr = Get-Prop $mat 'pbrMetallicRoughness' $null
                $bc = Get-Prop $pbr 'baseColorFactor' @(1, 1, 1, 1)
                $mats += ('{0} {1}' -f (Get-Prop $mat 'name' "mat$matIdx"), (Convert-ToHex $bc))
            }
            $mn = $posAcc.min; $mx = $posAcc.max
            foreach ($cx in @($mn[0], $mx[0])) {
                foreach ($cy in @($mn[1], $mx[1])) {
                    foreach ($cz in @($mn[2], $mx[2])) {
                        for ($i = 0; $i -lt 3; $i++) {
                            $v = $world[$i, 0] * [double]$cx + $world[$i, 1] * [double]$cy + $world[$i, 2] * [double]$cz + $world[$i, 3]
                            if ($v -lt $nmin[$i]) { $nmin[$i] = $v }
                            if ($v -gt $nmax[$i]) { $nmax[$i] = $v }
                        }
                    }
                }
            }
        }
        for ($i = 0; $i -lt 3; $i++) {
            if ($nmin[$i] -lt $state.gmin[$i]) { $state.gmin[$i] = $nmin[$i] }
            if ($nmax[$i] -gt $state.gmax[$i]) { $state.gmax[$i] = $nmax[$i] }
        }
        $state.total += $tri
        $sizeArgs = @(($nmax[0] - $nmin[0]), ($nmax[1] - $nmin[1]), ($nmax[2] - $nmin[2]))
        $taille = '{0:N2} x {1:N2} x {2:N2}' -f $sizeArgs
        $matText = ($mats | Select-Object -Unique) -join ' / '
        $nodeName = Get-Prop $node 'name' "node$idx"
        $meshName = Get-Prop $mesh 'name' "mesh$meshIdx"
        $minY = [math]::Round($nmin[1], 3)
        $state.rows.Add([pscustomobject]@{
                Noeud    = $nodeName
                Maillage = $meshName
                Matiere  = $matText
                Tri      = $tri
                Taille   = $taille
                MinY     = $minY
            })
    }
    foreach ($child in (Get-Prop $node 'children' @())) { Invoke-Walk ([int]$child) $world }
}

$sceneIdx = [int](Get-Prop $g 'scene' 0)
foreach ($root in $g.scenes[$sceneIdx].nodes) { Invoke-Walk ([int]$root) (New-Identity) }

"Fichier : {0} ({1:N0} octets)" -f (Split-Path $Path -Leaf), $bytes.Length
"Generateur : {0}" -f (Get-Prop $g.asset 'generator' '?')
"Noeuds : {0}, maillages : {1}, matieres : {2}, images : {3}, animations : {4}" -f @($g.nodes).Count, @($g.meshes).Count, @(Get-Prop $g 'materials' @()).Count, @(Get-Prop $g 'images' @()).Count, @(Get-Prop $g 'animations' @()).Count
"Extensions : {0}" -f ((Get-Prop $g 'extensionsUsed' @()) -join ', ')
"Triangles en tout : {0}" -f $state.total
"Boite : X {0:N3} .. {1:N3} | Y {2:N3} .. {3:N3} | Z {4:N3} .. {5:N3}" -f $state.gmin[0], $state.gmax[0], $state.gmin[1], $state.gmax[1], $state.gmin[2], $state.gmax[2]
"Taille (L x H x P) : {0:N2} x {1:N2} x {2:N2}" -f ($state.gmax[0] - $state.gmin[0]), ($state.gmax[1] - $state.gmin[1]), ($state.gmax[2] - $state.gmin[2])
"Centre au sol : X {0:N3}, Z {1:N3}" -f (($state.gmin[0] + $state.gmax[0]) / 2), (($state.gmin[2] + $state.gmax[2]) / 2)
$state.rows | Format-Table -AutoSize | Out-String -Width 250

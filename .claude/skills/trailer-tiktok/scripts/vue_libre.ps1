# Vérifie que la vue 3D de Studio n'est couverte par aucune autre fenêtre (navigateur, notification, Roblox Player…),
# sans faire de capture : on demande à Windows quel programme est sous 9 points de la région filmée.
#   pwsh -File vue_libre.ps1 <x> <y> <w> <h> [attente_max_s=0]
# Rend « libre » (code 0) ou la liste des programmes qui couvrent la vue (code 1). Avec une attente, réessaie
# toutes les 1,5 s (une notification disparaît seule au bout de quelques secondes).
param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$Wait = 0)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class VueLibre {
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[VueLibre]::SetProcessDPIAware() | Out-Null
$deadline = (Get-Date).AddSeconds($Wait)
do {
    $bad = @()
    foreach ($fx in 0.01, 0.5, 0.99) {
        foreach ($fy in 0.01, 0.5, 0.99) {
            $p = New-Object VueLibre+POINT
            $p.X = [int]($X + $W * $fx); $p.Y = [int]($Y + $H * $fy)
            # (PowerShell ne distingue pas $h de $H : ne pas réutiliser le nom du paramètre de hauteur)
            $hwnd = [VueLibre]::GetAncestor([VueLibre]::WindowFromPoint($p), 2)
            $id = 0; [VueLibre]::GetWindowThreadProcessId($hwnd, [ref]$id) | Out-Null
            $name = (Get-Process -Id $id -ErrorAction SilentlyContinue).ProcessName
            if ($name -ne "RobloxStudioBeta") { $bad += "$name@$($p.X),$($p.Y)" }
        }
    }
    if ($bad.Count -eq 0) { "libre"; exit 0 }
    if ((Get-Date) -ge $deadline) { break }
    Start-Sleep -Milliseconds 1500
} while ($true)
"couverte : " + (($bad | Sort-Object -Unique) -join ", ")
exit 1

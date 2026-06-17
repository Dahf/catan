# Führt die GUT-Tests headless aus.
# Aufruf:  ./run_tests.ps1            (alle Tests in test/)
#          ./run_tests.ps1 test_x.gd  (einzelne Datei)
param([string]$File = "")

$Godot = "C:\Users\silas\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"
$gutArgs = @("--headless", "--path", ".", "-s", "res://addons/gut/gut_cmdln.gd")
if ($File -ne "") {
    $gutArgs += "-gtest=res://test/$File"
} else {
    $gutArgs += "-gdir=res://test"
}
$gutArgs += "-gexit"
& $Godot @gutArgs

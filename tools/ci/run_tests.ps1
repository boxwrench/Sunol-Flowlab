param (
    [string]$GodotPath = "godot"
)

Write-Host "Running GUT tests with: $GodotPath"
& $GodotPath --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $LASTEXITCODE

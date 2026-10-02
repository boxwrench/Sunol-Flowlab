param([Parameter(Mandatory = $true)][string]$GodotPath)

# Run from any directory; keep all evidence inside the repository.
$repositoryPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$captureScript = 'tools/verification/capture_wp45.gd'
& $GodotPath --path $repositoryPath --resolution 1600x900 --rendering-method gl_compatibility -s $captureScript -- --wp47
if ($LASTEXITCODE -ne 0) { throw 'Startup/high-alarm/outage capture failed.' }

$initialPath = Join-Path $repositoryPath 'config/plants/phase3_headworks/initial_conditions.json'
$originalInitial = [IO.File]::ReadAllText($initialPath)
try {
    # Valid input fixture: empty channel, all basin outlet valves closed. The
    # actual main-scene bootstrap loads this config through the production loader.
    $fixture = $originalInitial | ConvertFrom-Json
    foreach ($state in $fixture.unit_states) {
        if ($state.unit_id -eq 'APPLIED_CHANNEL_01') { $state.volume_m3 = 0.0 }
    }
    foreach ($state in $fixture.actuator_states) {
        if ($state.actuator_id -in @('VALVE_OUT_BASIN_01', 'VALVE_OUT_BASIN_02',
                'VALVE_OUT_BASIN_03', 'VALVE_OUT_BASIN_04', 'VALVE_OUT_BASIN_05')) {
            $state.position = 0.0
            $state.commanded_position = 0.0
        }
    }
    [IO.File]::WriteAllText($initialPath, ($fixture | ConvertTo-Json -Depth 10) +
        [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    & $GodotPath --path $repositoryPath --resolution 1600x900 --rendering-method gl_compatibility -s $captureScript -- --wp47-low
    if ($LASTEXITCODE -ne 0) { throw 'Low-alarm capture failed.' }
} finally {
    # Restore exact content even if the capture fails. No persistent config change.
    [IO.File]::WriteAllText($initialPath, $originalInitial, [Text.UTF8Encoding]::new($false))
}

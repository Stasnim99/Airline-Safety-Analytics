<#
This script is the data backend for the aviation safety site.
It reads the NTSB Aviation Accident Database (a file called avall.mdb, which comes from
avall.zip downloaded from https://data.ntsb.gov/avdata) and turns the raw records into a
handful of small JSON files. Those JSON files are the only thing the website actually
loads in the browser, so nothing here runs live on the site itself. You run this script
once whenever you want to refresh the data, and it rewrites everything in data/processed.

Usage: pwsh scripts/process_ntsb.ps1
Requires: data/raw/avall/avall.mdb to exist (see README for how to fetch it),
and the 64 bit "Microsoft Access Driver (*.mdb, *.accdb)" ODBC driver installed
on the machine running this script (Windows normally already has it).
#>

# stop the whole script the moment anything fails, instead of continuing with bad data
$ErrorActionPreference = "Stop"

# figure out where this script lives so the paths below work no matter which folder
# you run the script from
$root = Split-Path -Parent $PSScriptRoot
$mdb = Join-Path $root "data\raw\avall\avall.mdb"
$outDir = Join-Path $root "data\processed"

# the database keeps growing as new accidents are added, so we lock the analysis to a
# fixed window of full calendar years. 2025 is the newest complete year at the time this
# was written; the current year is left out of yearly trend charts because it is still
# only partly reported and would look like an artificial dip
$minYear = 2008
$maxYear = 2025

if (-not (Test-Path $mdb)) {
    throw "Missing $mdb. Download avall.zip from https://data.ntsb.gov/avdata and extract it there first."
}

# open a connection to the Access database file through ODBC, the same way Excel or
# Access itself would read it
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "Driver={Microsoft Access Driver (*.mdb, *.accdb)};Dbq=$mdb;"
$conn.Open()

# small helper so the rest of the script can run a SQL query and get back a plain list
# of objects, instead of repeating the ODBC reader boilerplate every time
function Query($sql) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $reader = $cmd.ExecuteReader()
    $rows = [System.Collections.Generic.List[object]]::new()
    $cols = @()
    for ($i = 0; $i -lt $reader.FieldCount; $i++) { $cols += $reader.GetName($i) }
    while ($reader.Read()) {
        $row = [ordered]@{}
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $v = $reader.GetValue($i)
            if ($v -is [DBNull]) { $v = $null }
            $row[$cols[$i]] = $v
        }
        $rows.Add([pscustomobject]$row)
    }
    $reader.Close()
    return $rows
}

# small helper that saves any PowerShell object as a formatted JSON file in the
# processed data folder, which is the folder the website actually reads from
function WriteJson($obj, $name) {
    $path = Join-Path $outDir $name
    $obj | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding utf8
    Write-Output "wrote $path"
}

# section 1: accidents per year, split into total events and fatal events.
# this feeds the trend line chart at the top of the site.
$rows = Query "SELECT ev_year, COUNT(*) AS total, SUM(IIF(ev_highest_injury='FATL',1,0)) AS fatal FROM events WHERE ev_year BETWEEN $minYear AND $maxYear GROUP BY ev_year ORDER BY ev_year"
$byYear = $rows | ForEach-Object { [ordered]@{ year = [int]$_.ev_year; total = [int]$_.total; fatal = [int]$_.fatal } }
WriteJson $byYear "accidents_by_year.json"

# section 2: accidents grouped by aircraft category (airplane, helicopter, glider, and so on).
# the database stores this as a short code, so catDict below translates each code into the
# full word the chart should display. a few of the rarer codes were not documented anywhere
# in the database itself, so those labels were filled in by hand after checking the raw values.
$catDict = @{ AIR="Airplane"; BALL="Balloon"; BLIM="Blimp"; GLI="Glider"; GYRO="Gyrocraft"; HELI="Helicopter"; PLFT="Powered Lift"; ULTR="Ultralight"; UNK="Unknown"; WSFT="Weight Shift Control"; PPAR="Powered Parachute"; RCKT="Rocket" }
$rows = Query "SELECT a.acft_category AS cat, COUNT(*) AS n FROM aircraft a INNER JOIN events e ON a.ev_id = e.ev_id WHERE e.ev_year BETWEEN $minYear AND $maxYear GROUP BY a.acft_category"
$typeCounts = @{}
foreach ($r in $rows) {
    $c = $r.cat
    # some rows have a blank category and some use the explicit "UNK" code, so both cases
    # are folded into the same "Unknown" bucket rather than showing up as two separate bars
    $label = if ($c -and $catDict.ContainsKey($c)) { $catDict[$c] } elseif ($c) { $c } else { "Unknown" }
    if (-not $typeCounts.ContainsKey($label)) { $typeCounts[$label] = 0 }
    $typeCounts[$label] += [int]$r.n
}
$byType = $typeCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    [ordered]@{ type = $_.Key; count = [int]$_.Value }
}
WriteJson $byType "accidents_by_aircraft_type.json"

# section 3: accidents grouped by phase of flight (takeoff, cruise, landing, and so on).
# note for anyone reading this later: the column that was supposed to hold this, called
# phase_flt_spec, turned out to be empty for every single row in this dataset, so it could
# not be used. instead this section reads Events_Sequence.Occurrence_Description, a plain
# text field NTSB writes for the main event of each accident, which always starts with the
# phase name written out, for example "Landing, landing roll" or "Enroute, cruise". the
# list below matches that starting text against the standard phase names and groups
# everything into one clean set of categories for the chart.
$phasePrefixes = [ordered]@{
    "Standing"      = "Standing"
    "Taxi"          = "Taxi"
    "Takeoff"       = "Takeoff"
    "Initial climb" = "Climb"
    "Climb"         = "Climb"
    "Enroute"       = "Cruise"
    "Descent"       = "Descent"
    "Approach"      = "Approach"
    "Landing"       = "Landing"
    "Maneuvering"   = "Maneuvering"
    "Hover"         = "Hover"
    "Unknown"       = "Unknown"
}
$rows = Query "SELECT s.Occurrence_Description AS descr FROM Events_Sequence s INNER JOIN events e ON s.ev_id = e.ev_id WHERE s.Defining_ev=True AND e.ev_year BETWEEN $minYear AND $maxYear AND s.Occurrence_Description IS NOT NULL"
$phaseCounts = @{}
foreach ($r in $rows) {
    $text = $r.descr
    $label = "Other"
    foreach ($prefix in $phasePrefixes.Keys) {
        if ($text.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $label = $phasePrefixes[$prefix]
            break
        }
    }
    if (-not $phaseCounts.ContainsKey($label)) { $phaseCounts[$label] = 0 }
    $phaseCounts[$label]++
}
$byPhase = $phaseCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    [ordered]@{ phase = $_.Key; count = [int]$_.Value }
}
WriteJson $byPhase "accidents_by_phase.json"

# section 4: accidents grouped by root cause category (personnel error, aircraft failure,
# environment, and so on). the Findings table stores each cause as one long readable
# sentence built from broad category down to specific detail, separated by dashes, for
# example "Personnel issues, Action or decision, Info processing, Pilot". only the first
# piece of that sentence is the broad category we want for the chart, so it is split off
# and everything after it is dropped. Cause_Factor='C' keeps only actual causes and skips
# contributing factors, which are recorded separately in the same table.
$rows = Query "SELECT f.finding_description AS descr FROM Findings f INNER JOIN events e ON f.ev_id = e.ev_id WHERE e.ev_year BETWEEN $minYear AND $maxYear AND f.Cause_Factor='C' AND f.finding_description IS NOT NULL"
$causeCounts = @{}
foreach ($r in $rows) {
    $top = ($r.descr -split '-')[0].Trim()
    if (-not $causeCounts.ContainsKey($top)) { $causeCounts[$top] = 0 }
    $causeCounts[$top]++
}
$byCause = $causeCounts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    [ordered]@{ category = $_.Key; count = [int]$_.Value }
}
WriteJson $byCause "accidents_by_cause.json"

# section 5: one row per accident with its location and severity, for the map on the site.
# latitude and longitude are rounded to 3 decimal places (about 100 meters of precision),
# which is plenty for a dot on a hotspot map and keeps the JSON file much smaller than
# storing the full precision the database provides.
$rows = Query "SELECT ev_year, ev_highest_injury AS sev, dec_latitude AS lat, dec_longitude AS lon FROM events WHERE ev_year BETWEEN $minYear AND $maxYear AND dec_latitude IS NOT NULL AND dec_longitude IS NOT NULL"
$locations = $rows | ForEach-Object {
    [ordered]@{
        year = [int]$_.ev_year
        sev  = $(if ($_.sev) { $_.sev } else { "UNK" })
        lat  = [Math]::Round([double]$_.lat, 3)
        lon  = [Math]::Round([double]$_.lon, 3)
    }
}
WriteJson $locations "accident_locations.json"

$conn.Close()
Write-Output "Done."

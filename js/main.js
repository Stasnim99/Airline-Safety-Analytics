/*
This file is the entry point for the page. It fetches each precomputed JSON
file out of data/processed, and once a file has loaded, hands its contents to
the matching draw function from charts.js or map.js. There is no server here,
these fetch calls just read plain files sitting next to the page, the same
files that scripts/process_ntsb.ps1 generates.
*/

// small helper that fetches one JSON file and turns a failed request into a
// clear message in the browser console instead of a silent blank chart
async function loadJson(path) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`Could not load ${path} (status ${response.status})`);
  }
  return response.json();
}

async function init() {
  try {
    const [byYear, byType, byPhase, byCause, locations] = await Promise.all([
      loadJson("data/processed/accidents_by_year.json"),
      loadJson("data/processed/accidents_by_aircraft_type.json"),
      loadJson("data/processed/accidents_by_phase.json"),
      loadJson("data/processed/accidents_by_cause.json"),
      loadJson("data/processed/accident_locations.json")
    ]);

    drawYearChart(byYear);
    drawAircraftTypeChart(byType);
    drawPhaseChart(byPhase);
    drawCauseChart(byCause);
    drawMap(locations);
  } catch (err) {
    // if any file fails to load, this is almost always because the page is
    // being opened straight from disk instead of through a local web server,
    // browsers block fetch requests to local files for security reasons
    console.error(err);
  }
}

init();

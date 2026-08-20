/*
This file draws the accident location map using Leaflet, a mapping library, plus
its marker cluster plugin, which groups nearby markers together into one circle
until the visitor zooms in close enough to see individual accidents. main.js
calls drawMap once the location data has finished loading.
*/

// which color each severity level gets on the map, matching the same severity
// colors defined in css/style.css so the legend text below and the markers
// on the map always agree with each other
const SEVERITY_COLORS = {
  NONE: cssVar("--sev-none"),
  MINR: cssVar("--sev-minor"),
  SERS: cssVar("--sev-serious"),
  FATL: cssVar("--sev-fatal"),
  UNK:  cssVar("--sev-unknown")
};

// the same codes, but written out in plain words for the legend and for the
// popup that appears when a visitor clicks a marker
const SEVERITY_LABELS = {
  NONE: "No injury",
  MINR: "Minor injury",
  SERS: "Serious injury",
  FATL: "Fatal",
  UNK:  "Unknown"
};

function drawMap(rows) {
  const map = L.map("map", { scrollWheelZoom: false }).setView([39.5, -98.35], 4);

  // the map tiles themselves, the actual picture of the world underneath the
  // markers, come from OpenStreetMap, a free and openly licensed map source
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors",
    maxZoom: 18
  }).addTo(map);

  // markers are grouped into a cluster layer so thirty thousand points do not
  // freeze the browser, nearby points collapse into one numbered circle until
  // the visitor zooms in far enough to tell them apart
  const cluster = L.markerClusterGroup({ maxClusterRadius: 40 });

  rows.forEach(r => {
    const color = SEVERITY_COLORS[r.sev] || SEVERITY_COLORS.UNK;
    const label = SEVERITY_LABELS[r.sev] || SEVERITY_LABELS.UNK;
    const marker = L.circleMarker([r.lat, r.lon], {
      radius: 5,
      color: color,
      fillColor: color,
      fillOpacity: 0.8,
      weight: 1
    });
    marker.bindPopup(`${label} accident, ${r.year}`);
    cluster.addLayer(marker);
  });

  map.addLayer(cluster);
  drawMapLegend();
}

// builds the small color key shown under the map, one dot and label per
// severity level, so color is never the only way to read what a marker means
function drawMapLegend() {
  const legend = document.getElementById("map-legend");
  const order = ["FATL", "SERS", "MINR", "NONE", "UNK"];
  legend.innerHTML = order.map(code => `
    <span class="legend-item">
      <span class="legend-dot" style="background:${SEVERITY_COLORS[code]}"></span>
      ${SEVERITY_LABELS[code]}
    </span>
  `).join("");
}

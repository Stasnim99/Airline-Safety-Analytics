/*
This file only knows how to draw charts. It does not know where the data comes
from, that part lives in main.js. Every function here takes plain JavaScript
data (an array of small objects) and hands it to Plotly, the charting library
loaded in index.html.

Colors are read from the CSS variables defined in css/style.css instead of being
written as hex codes here, so a chart automatically switches to the dark palette
when the visitor's system is in dark mode, without this file needing to know
anything about themes at all.
*/

// small helper that reads one CSS variable off the page so the charts always
// match whatever colors style.css currently has set, in either light or dark mode
function cssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

// settings shared by every chart so the page has one consistent look instead of
// each chart reinventing its own fonts, gridline color, and margins
function baseLayout(extra) {
  const layout = {
    paper_bgcolor: "transparent",
    plot_bgcolor: "transparent",
    font: { family: "system-ui, -apple-system, Segoe UI, sans-serif", color: cssVar("--text-secondary") },
    margin: { l: 48, r: 16, t: 8, b: 40 },
    xaxis: { gridcolor: cssVar("--gridline"), linecolor: cssVar("--baseline"), zeroline: false },
    yaxis: { gridcolor: cssVar("--gridline"), linecolor: cssVar("--baseline"), zeroline: false, rangemode: "tozero" },
    legend: { orientation: "h", y: 1.1 }
  };
  return Object.assign(layout, extra);
}

// options passed to Plotly on every chart so the toolbar stays out of the way
// and the chart resizes itself when the browser window changes size
const basicConfig = { responsive: true, displayModeBar: false };

// chart 1: accidents per year, drawn as two lines, total accidents and fatal
// accidents, sharing one axis so the reader can compare them directly
function drawYearChart(rows) {
  const years = rows.map(r => r.year);
  const totals = rows.map(r => r.total);
  const fatals = rows.map(r => r.fatal);

  const traceTotal = {
    x: years, y: totals, name: "Total accidents",
    mode: "lines", type: "scatter",
    line: { color: cssVar("--series-total"), width: 2 }
  };
  const traceFatal = {
    x: years, y: fatals, name: "Fatal accidents",
    mode: "lines", type: "scatter",
    line: { color: cssVar("--series-fatal"), width: 2 }
  };

  Plotly.newPlot("chart-year", [traceTotal, traceFatal], baseLayout({}), basicConfig);
}

// chart 2 and chart 3 are both simple ranked bar charts, one bar per category,
// sorted from the largest value to the smallest. since there is only one measure
// being shown (a count), every bar uses the same single color rather than a
// different color per bar, the color is not standing in for a second variable
function drawRankedBarChart(divId, rows, labelKey, valueKey) {
  const sorted = rows.slice().sort((a, b) => b[valueKey] - a[valueKey]);
  const labels = sorted.map(r => r[labelKey]);
  const values = sorted.map(r => r[valueKey]);

  const trace = {
    x: values, y: labels, type: "bar", orientation: "h",
    marker: { color: cssVar("--series-single") }
  };

  Plotly.newPlot(divId, [trace], baseLayout({
    yaxis: { autorange: "reversed", gridcolor: cssVar("--gridline"), linecolor: cssVar("--baseline") },
    margin: { l: 140, r: 16, t: 8, b: 40 }
  }), basicConfig);
}

function drawAircraftTypeChart(rows) {
  drawRankedBarChart("chart-type", rows, "type", "count");
}

function drawPhaseChart(rows) {
  drawRankedBarChart("chart-phase", rows, "phase", "count");
}

function drawCauseChart(rows) {
  // this chart is wide, so it is drawn as vertical bars instead of the horizontal
  // bars used for the two narrower charts above, everything else about it is the
  // same single color ranked bar chart
  const sorted = rows.slice().sort((a, b) => b.count - a.count);
  const labels = sorted.map(r => r.category);
  const values = sorted.map(r => r.count);

  const trace = {
    x: labels, y: values, type: "bar",
    marker: { color: cssVar("--series-single") }
  };

  Plotly.newPlot("chart-cause", [trace], baseLayout({}), basicConfig);
}

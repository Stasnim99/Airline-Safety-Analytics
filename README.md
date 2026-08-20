# Aviation Safety Analytics

A static, hand built website analyzing eighteen years of civil aviation accidents (2008
through 2025), sourced directly from the **NTSB Aviation Accident Database**. Unlike a live
flight tracker, this project is built around historical safety analytics: every chart and
the accident map below are computed offline from roughly 31,000 real NTSB records, not
fetched from a live API. There is no backend and no build step, just plain HTML, CSS, and
JavaScript rendering precomputed data.

You can view the website here: https://stasnim99.github.io/Airline-Safety-Analytics/

## Contents

| File | Description |
|---|---|
| `index.html` | The page itself — one section per chart, plus the accident map. |
| `css/style.css` | Colors and layout, defined once as CSS variables (light and dark mode). |
| `js/charts.js` | Draws every Plotly chart (the year trend line and the ranked bar charts). |
| `js/map.js` | Draws the Leaflet map of accident locations, clustered and colored by severity. |
| `js/main.js` | Loads the processed JSON data and calls the chart and map drawing functions. |
| `data/processed/*.json` | The precomputed aggregate files the page actually reads. |
| `scripts/process_ntsb.ps1` | Reads the raw NTSB database and regenerates every processed JSON file. |

## Accidents Per Year
![Accidents Per Year](https://raw.githubusercontent.com/Stasnim99/Airline-Safety-Analytics/main/screenshots/accidents-per-year.png)

Total reported accidents versus accidents with at least one fatality, by year. Both lines
trend downward over the period, and the fatal share declines faster than raw volume does,
including the sharp dip in 2020 when general aviation activity dropped.

**Analytical use:** separating total accidents from fatal accidents is what distinguishes
"less flying" from "safer flying." A falling total count alongside a shrinking fatal share
points to a genuine safety improvement, not just fewer flights in the air.

## Aircraft Category and Phase of Flight
![Aircraft Category and Phase of Flight](https://raw.githubusercontent.com/Stasnim99/Airline-Safety-Analytics/main/screenshots/aircraft-type-and-phase.png)

Which kind of aircraft was involved, and what the aircraft was doing when the accident
sequence began. Airplanes account for the large majority of records, consistent with their
share of overall civil aviation traffic. Landing is by far the single largest phase of
flight, followed by cruise, maneuvering, takeoff, approach, and climb.

**Analytical use:** the phase of flight breakdown pinpoints where in a flight risk actually
concentrates. Landing and approach together account for a large share of accidents, which
lines up with where the industry has focused training and technology investment, such as
stabilized approach criteria and runway safety programs.

## Root Cause Categories
![Root Cause Categories](https://raw.githubusercontent.com/Stasnim99/Airline-Safety-Analytics/main/screenshots/root-cause-categories.png)

The top level category of every finding NTSB investigators marked as an actual cause, as
opposed to a contributing factor, summed across every accident in the period.

**Analytical use:** personnel issues and aircraft issues sit nearly tied as the two largest
categories. That near parity complicates the common assumption that human error dominates
general aviation accidents on its own; mechanical and aircraft related factors turn out to
be nearly as consequential, which matters for how training investment gets weighed against
maintenance and mechanical inspection programs.

## Accident Map
![Accident Map](https://raw.githubusercontent.com/Stasnim99/Airline-Safety-Analytics/main/screenshots/accident-map.png)

Every geocoded accident in the period, plotted with Leaflet and clustered so nearby points
collapse into one number until zoomed in. Color shows the highest injury level recorded for
that accident, from fatal down to no injury.

**Analytical use:** the clusters concentrate around regions of dense general aviation
traffic rather than spreading evenly across the country. Reading raw accident counts by
location without accounting for how much flying happens there would overstate the risk in
high traffic areas and understate it elsewhere.

## In progress

Two additional sections are planned but not built yet, both blocked on the same problem:
the source data sits behind a search form rather than a plain bulk download.

- **Wildlife strikes**, from the FAA Wildlife Strike Database — breakdowns by airport,
  month, and damage severity.
- **Common contributing factors**, from NASA's Aviation Safety Reporting System — the most
  frequent contributing factor terms drawn from de-identified incident narratives.

## How it works

- **Data source** — the NTSB Aviation Accident Database (`avall.mdb`), an Access database
  published at data.ntsb.gov, queried directly through ODBC.
- **Processing** — an offline PowerShell script reads the raw database, aggregates it, and
  writes small JSON files. Nothing on the live page is fetched from a database or API; the
  browser only ever reads those precomputed JSON files.
- **Charts and map** — Plotly.js draws the line and bar charts; Leaflet, with its marker
  cluster plugin, draws the accident map over OpenStreetMap tiles.

## Data quality and sourcing notes

1. **The analysis is scoped to full calendar years, 2008 through 2025.** The current year
   is excluded from yearly figures since it is still only partially reported and would show
   up as a misleading dip rather than a real trend.
2. **Phase of flight is derived from investigator narrative text, not a dedicated code
   field.** The database column intended for this, `phase_flt_spec`, is empty for every
   record in this dataset; phase is instead read from the free text NTSB writes for each
   accident's defining event, which reliably starts with the phase name.
3. **Root cause categories are the top level segment of each finding's full description
   text**, as written by NTSB investigators, not a separate coded category field — that
   field exists in the schema but was left blank for every record.
4. **A handful of aircraft category codes were not documented anywhere in the database
   itself** (weight shift control, powered parachute, and rocket among them) and were
   labeled by checking the raw values directly rather than left unlabeled.

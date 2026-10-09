"""Independent NWS procedure fixture; inputs/output in F until final conversion.
Source: https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml
Regeneration is explicit; this script does not import HeatStressR.
"""
import csv
import math
from pathlib import Path

def nws(t, rh):
    simple = (0.5 * (t + 61 + (t - 68) * 1.2 + rh * 0.094) + t) / 2
    if simple < 80:
        return simple
    value = (-42.379 + 2.04901523 * t + 10.14333127 * rh
             - 0.22475541 * t * rh - 0.00683783 * t * t
             - 0.05481717 * rh * rh + 0.00122874 * t * t * rh
             + 0.00085282 * t * rh * rh - 0.00000199 * t * t * rh * rh)
    if rh < 13 and 80 <= t <= 112:
        value -= (13 - rh) / 4 * math.sqrt((17 - abs(t - 95)) / 17)
    if rh > 85 and 80 <= t <= 87:
        value += (rh - 85) / 10 * (87 - t) / 5
    return value

out = Path('tests/testthat/fixtures/nws-heat-index.csv')
with out.open('w', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['temperature_f', 'hurs', 'heat_index_c'])
    for t in [32, 68, 77, 79.999, 80, 80.001, 85, 87, 87.001, 90, 95, 112, 112.001]:
        for rh in [0, 5, 10, 13, 13.001, 50, 85, 85.001, 99, 100]:
            writer.writerow([t, rh, (nws(t, rh) - 32) / 1.8])

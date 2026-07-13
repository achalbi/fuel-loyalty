#!/usr/bin/env python3
"""Nayara-anchored design token generator for fuel-loyalty.
Anchors extracted from the official Nayara Energy logo (pixel-verified):
  navy #10447C (wordmark + lead ribbon), cyan #0080A0 (mid ribbon),
  green #18945C (leaf ribbon), sky #249ADF (nayaraenergy.com theme-color).
Generates perceptually-even OKLCH ramps, snaps the anchor hex exactly onto
its nearest step, gamut-maps, and emits JSON for downstream file generation.
"""
import json
from coloraide import Color

STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]
L = {50: .985, 100: .955, 200: .90, 300: .83, 400: .74, 500: .66,
     600: .58, 700: .50, 800: .43, 900: .365, 950: .29}
CMULT = {50: .14, 100: .25, 200: .45, 300: .66, 400: .86, 500: 1.0,
         600: 1.0, 700: .95, 800: .86, 900: .74, 950: .58}

def hexof(c):
    return c.convert('srgb').fit(method='oklch-chroma').to_string(hex=True, upper=False)

def ramp(anchor_hex, name, chroma_scale=1.0, force_step=None):
    a = Color(anchor_hex).convert('oklch')
    La, Ca, Ha = a['lightness'], a['chroma'], a['hue']
    step_a = force_step or min(STEPS, key=lambda s: abs(L[s] - La))
    cpeak = (Ca / CMULT[step_a]) * chroma_scale
    out = {}
    for s in STEPS:
        if s == step_a and chroma_scale == 1.0:
            out[s] = anchor_hex.lower()
        else:
            c = Color('oklch', [L[s], min(cpeak * CMULT[s], 0.32), Ha])
            out[s] = hexof(c)
    return out, step_a

def neutral_ramp(hue):
    out = {}
    nl = {50: .985, 100: .962, 200: .922, 300: .868, 400: .742, 500: .626,
          600: .52, 700: .44, 800: .36, 900: .28, 950: .205}
    nc = {50: .003, 100: .004, 200: .006, 300: .008, 400: .011, 500: .013,
          600: .014, 700: .015, 800: .016, 900: .018, 950: .020}
    for s in STEPS:
        out[s] = hexof(Color('oklch', [nl[s], nc[s], hue]))
    return out

navy, navy_step = ramp('#10447C', 'navy')
cyan, cyan_step = ramp('#0080A0', 'cyan')
green, green_step = ramp('#18945C', 'green')
sky, sky_step = ramp('#249ADF', 'sky')
# Functional (non-brand, tuned to sit with the palette)
amber, _ = ramp('#F5A524', 'amber')          # points / rewards gold
red, _ = ramp('#DF2935', 'red')              # error
navy_h = Color('#10447C').convert('oklch')['hue']
neutral = neutral_ramp(navy_h)               # navy-tinted neutrals

# Dark-mode navy surfaces (deep, slightly blue)
dark_surfaces = {
    'canvas':  hexof(Color('oklch', [.165, .022, navy_h])),
    'surface': hexof(Color('oklch', [.205, .024, navy_h])),
    'raised':  hexof(Color('oklch', [.245, .026, navy_h])),
    'overlay': hexof(Color('oklch', [.30, .028, navy_h])),
}

ramps = {'navy': navy, 'cyan': cyan, 'green': green, 'sky': sky,
         'amber': amber, 'red': red, 'neutral': neutral}

def cr(fg, bg):
    return round(Color(fg).contrast(bg, method='wcag21'), 2)

# ---- Contrast verification of the semantic pairs we intend to ship ----
white = '#ffffff'
checks = [
    # (label, fg, bg, min_required)
    ('onPrimary on primary (light)', white, navy[700], 4.5),
    ('primary text on canvas (light)', navy[700], neutral[50], 4.5),
    ('text.primary on surface (light)', neutral[950], white, 7.0),
    ('text.secondary on surface (light)', neutral[600], white, 4.5),
    ('text.tertiary on surface (light, large/aux)', neutral[500], white, 3.0),
    ('link on surface (light)', sky[700], white, 4.5),
    ('onAccent on accent cyan-700 (light)', white, cyan[700], 4.5),
    ('success text green-700 on white', green[700], white, 4.5),
    ('error text red-600 on white', red[600], white, 4.5),
    ('onError white on red-600', white, red[600], 4.5),
    ('warning text amber-800 on amber-100', amber[800], amber[100], 4.5),
    ('points amber-800 on amber-50', amber[800], amber[50], 4.5),
    ('onPrimaryContainer navy-900 on navy-100', navy[900], navy[100], 4.5),
    ('onSuccessContainer green-900 on green-100', green[900], green[100], 4.5),
    # dark
    ('text.primary dark on canvas', '#f4f7fc', dark_surfaces['canvas'], 7.0),
    ('primary dark (sky-300) on surface', sky[300], dark_surfaces['surface'], 3.0),
    ('onPrimary dark navy-950 on sky-300', navy[950], sky[300], 4.5),
    ('text.secondary dark neutral-300 on surface', neutral[300], dark_surfaces['surface'], 4.5),
    ('success dark green-300 on surface', green[300], dark_surfaces['surface'], 4.5),
    ('error dark red-300 on surface', red[300], dark_surfaces['surface'], 4.5),
    ('amber-300 points on dark surface', amber[300], dark_surfaces['surface'], 4.5),
    ('link dark sky-300 on canvas', sky[300], dark_surfaces['canvas'], 4.5),
]
report, fails = [], 0
for label, fg, bg, need in checks:
    r = cr(fg, bg)
    ok = r >= need
    fails += (not ok)
    report.append(f"{'PASS' if ok else 'FAIL'}  {r:>5.2f} (need {need})  {label}  {fg} on {bg}")

result = {'ramps': ramps, 'dark_surfaces': dark_surfaces,
          'anchor_steps': {'navy': navy_step, 'cyan': cyan_step, 'green': green_step, 'sky': sky_step},
          'report': report, 'fails': fails}
with open('/tmp/tokens_gen.json', 'w') as f:
    json.dump(result, f, indent=1)
print('\n'.join(report))
print(f"\nFAILS: {fails}")
print('anchor steps:', result['anchor_steps'])
for n, r in ramps.items():
    print(n, ' '.join(f"{s}:{v}" for s, v in list(r.items())[:11]))
print('dark:', dark_surfaces)

#!/usr/bin/env python3
"""Emit design-tokens.json (DTCG), tokens.css, NayaraColor.kt from generated ramps."""
import json, re

G = json.load(open('/tmp/tokens_gen.json'))
R, DS = G['ramps'], G['dark_surfaces']
OUT = '/sessions/upbeat-funny-ritchie/mnt/fuel-loyalty/docs/design'

def ref(ramp, step): return R[ramp][str(step)]
WHITE, BLACK = '#ffffff', '#000000'

# ---------------- semantic map: key -> (light, dark) ----------------
SEM = {
 'bg.canvas':            (ref('neutral',50), DS['canvas']),
 'bg.surface':           (WHITE, DS['surface']),
 'bg.surfaceRaised':     (WHITE, DS['raised']),
 'bg.surfaceSunken':     (ref('neutral',100), '#050a10'),
 'bg.brand':             (ref('navy',900), ref('navy',900)),
 'bg.brandSubtle':       (ref('navy',50), '#0d2038'),
 'bg.inverse':           (ref('neutral',950), ref('neutral',50)),
 'text.primary':         (ref('neutral',950), '#f4f7fc'),
 'text.secondary':       (ref('neutral',600), ref('neutral',300)),
 'text.tertiary':        (ref('neutral',500), ref('neutral',400)),
 'text.disabled':        (ref('neutral',400), ref('neutral',600)),
 'text.inverse':         (WHITE, ref('neutral',950)),
 'text.onBrand':         (WHITE, WHITE),
 'text.brand':           (ref('navy',700), ref('sky',300)),
 'text.link':            (ref('sky',700), ref('sky',300)),
 'border.subtle':        (ref('neutral',100), '#18212d'),
 'border.default':       (ref('neutral',200), '#242f3c'),
 'border.strong':        (ref('neutral',300), '#37424f'),
 'border.focus':         (ref('sky',500), ref('sky',400)),
 'action.primary':           (ref('navy',700), ref('sky',300)),
 'action.primaryHover':      (ref('navy',800), ref('sky',200)),
 'action.primaryPressed':    (ref('navy',900), ref('sky',400)),
 'action.onPrimary':         (WHITE, ref('navy',950)),
 'action.primaryContainer':  (ref('navy',100), ref('navy',800)),
 'action.onPrimaryContainer':(ref('navy',900), ref('navy',100)),
 'action.secondary':         (ref('navy',50), '#14283f'),
 'action.onSecondary':       (ref('navy',800), ref('sky',200)),
 'action.disabledBg':        (ref('neutral',200), '#1b2531'),
 'action.onDisabled':        (ref('neutral',400), ref('neutral',600)),
 'accent.default':        (ref('cyan',600), ref('cyan',300)),
 'accent.onAccent':       (WHITE, ref('cyan',950)),
 'accent.container':      (ref('cyan',100), ref('cyan',900)),
 'accent.onContainer':    (ref('cyan',900), ref('cyan',100)),
 'status.success':           (ref('green',600), ref('green',300)),
 'status.successText':       (ref('green',700), ref('green',300)),
 'status.successContainer':  (ref('green',100), ref('green',900)),
 'status.onSuccessContainer':(ref('green',900), ref('green',100)),
 'status.warning':           (ref('amber',500), ref('amber',300)),
 'status.warningText':       (ref('amber',800), ref('amber',300)),
 'status.warningContainer':  (ref('amber',100), ref('amber',900)),
 'status.onWarningContainer':(ref('amber',900), ref('amber',100)),
 'status.error':             (ref('red',600), ref('red',300)),
 'status.errorText':         (ref('red',600), ref('red',300)),
 'status.errorContainer':    (ref('red',100), ref('red',900)),
 'status.onErrorContainer':  (ref('red',900), ref('red',100)),
 'status.info':              (ref('sky',600), ref('sky',300)),
 'status.infoContainer':     (ref('sky',100), ref('sky',900)),
 'status.onInfoContainer':   (ref('sky',900), ref('sky',100)),
 'reward.points':          (ref('amber',500), ref('amber',300)),
 'reward.pointsText':      (ref('amber',800), ref('amber',300)),
 'reward.pointsContainer': (ref('amber',50), '#2b1c05'),
 'reward.coin':            (ref('amber',400), ref('amber',400)),
 'fuel.petrol':            (ref('green',600), ref('green',400)),
 'fuel.diesel':            (ref('navy',700), ref('sky',400)),
 'fuel.premium':           (ref('amber',600), ref('amber',400)),
 'tier.member':            (ref('sky',500), ref('sky',400)),
 'tier.silver':            (ref('neutral',400), ref('neutral',300)),
 'tier.gold':              (ref('amber',400), ref('amber',300)),
 'tier.platinum':          (ref('neutral',800), ref('neutral',200)),
 'overlay.scrim':          ('rgba(8,15,24,0.60)', 'rgba(0,0,0,0.70)'),
 'overlay.hover':          ('rgba(17,24,32,0.04)', 'rgba(244,247,252,0.06)'),
 'overlay.pressed':        ('rgba(17,24,32,0.08)', 'rgba(244,247,252,0.10)'),
}

GRAD = {
 'brandRibbon': ('linear-gradient(135deg, #10447c 0%, #0080a0 55%, #18945c 100%)',)*2,
 'heroCard': ('linear-gradient(160deg, #052b54 0%, #10447c 55%, #00465c 100%)',
              'linear-gradient(160deg, #0f1822 0%, #10447c 60%, #00465c 100%)'),
 'goldShine': ('linear-gradient(120deg, #f8ba69 0%, #f5a524 45%, #cd7e00 100%)',)*2,
}

DIM = {  # dimensions in dp/px
 'space': {'none':0,'xxs':2,'xs':4,'sm':8,'md':12,'lg':16,'xl':20,'xxl':24,'x3l':32,'x4l':40,'x5l':48,'x6l':64,'x7l':80},
 'radius': {'xs':6,'sm':10,'md':14,'lg':18,'xl':22,'xxl':28,'full':999},
 'size': {'iconXs':16,'iconSm':20,'iconMd':24,'iconLg':28,'iconXl':32,'hitTarget':48,
          'buttonLg':52,'buttonMd':44,'buttonSm':36,'inputHeight':52,'tabBarHeight':64,
          'listRow':56,'listRowLg':72,'sheetHandleW':36,'sheetHandleH':4,'progressRing':10},
 'layout': {'screenMargin':16,'gutter':12,'cardPadding':20,'sectionGap':28,'maxContentWidth':480},
}
MOTION = {
 'duration': {'instant':80,'fast':140,'base':220,'gentle':320,'slow':480},
 'easing': {'standard':'cubic-bezier(0.2, 0, 0, 1)','emphasized':'cubic-bezier(0.05, 0.7, 0.1, 1)',
            'enter':'cubic-bezier(0, 0, 0, 1)','exit':'cubic-bezier(0.3, 0, 1, 1)'},
 'spring': {'press':{'stiffness':380,'damping':30},'bouncy':{'stiffness':170,'damping':22}},
}
TYPE = {
 'fontFamily': {'display':'Manrope','body':'system (Roboto / SF Pro)','numeric':'Manrope (tabular-nums)','indic':'Noto Sans (Devanagari/Gujarati fallback)'},
 'scale': {  # name: size/line weight tracking
  'displayLg':{'size':40,'line':46,'weight':800,'tracking':-0.5},
  'display':{'size':32,'line':38,'weight':800,'tracking':-0.25},
  'headline':{'size':24,'line':30,'weight':700,'tracking':0},
  'titleLg':{'size':20,'line':26,'weight':700,'tracking':0},
  'title':{'size':17,'line':24,'weight':600,'tracking':0},
  'bodyLg':{'size':16,'line':24,'weight':400,'tracking':0},
  'body':{'size':14,'line':20,'weight':400,'tracking':0},
  'bodySm':{'size':13,'line':18,'weight':400,'tracking':0},
  'labelLg':{'size':14,'line':20,'weight':600,'tracking':0.1},
  'label':{'size':12,'line':16,'weight':600,'tracking':0.3},
  'caption':{'size':11,'line':14,'weight':500,'tracking':0.3},
  'numericHero':{'size':44,'line':48,'weight':800,'tracking':-0.5},
  'numericLg':{'size':28,'line':32,'weight':800,'tracking':-0.25},
  'numeric':{'size':20,'line':24,'weight':700,'tracking':0},
 },
}
SHADOW = {
 'e1': '0 1px 2px rgba(16,24,40,0.06), 0 1px 3px rgba(16,24,40,0.10)',
 'e2': '0 2px 4px -1px rgba(16,24,40,0.06), 0 4px 8px -2px rgba(16,24,40,0.10)',
 'e3': '0 4px 6px -2px rgba(16,24,40,0.05), 0 8px 16px -4px rgba(16,24,40,0.12)',
 'e4': '0 16px 32px -8px rgba(16,24,40,0.16)',
}

# ---------------- 1) DTCG design-tokens.json ----------------
dtcg = {'$schema': 'https://design-tokens.github.io/community-group/format/',
        'color': {'primitive': {}, 'semantic': {'light': {}, 'dark': {}}, 'gradient': {'light': {}, 'dark': {}}},
        'dimension': {}, 'typography': {}, 'motion': {}, 'shadow': {}}
for name, ramp in R.items():
    dtcg['color']['primitive'][name] = {str(s): {'$type': 'color', '$value': v} for s, v in ramp.items()}
dtcg['color']['primitive']['white'] = {'$type': 'color', '$value': WHITE}
dtcg['color']['primitive']['black'] = {'$type': 'color', '$value': BLACK}
dtcg['color']['primitive']['darkSurface'] = {k: {'$type': 'color', '$value': v} for k, v in DS.items()}
for key, (lv, dv) in SEM.items():
    grp, leaf = key.split('.')
    dtcg['color']['semantic']['light'].setdefault(grp, {})[leaf] = {'$type': 'color', '$value': lv}
    dtcg['color']['semantic']['dark'].setdefault(grp, {})[leaf] = {'$type': 'color', '$value': dv}
for key, (lv, dv) in GRAD.items():
    dtcg['color']['gradient']['light'][key] = {'$type': 'gradient', '$value': lv}
    dtcg['color']['gradient']['dark'][key] = {'$type': 'gradient', '$value': dv}
for grp, d in DIM.items():
    dtcg['dimension'][grp] = {k: {'$type': 'dimension', '$value': f'{v}px'} for k, v in d.items()}
dtcg['typography']['fontFamily'] = {k: {'$type': 'fontFamily', '$value': v} for k, v in TYPE['fontFamily'].items()}
dtcg['typography']['scale'] = {k: {'$type': 'typography', '$value': {
    'fontSize': f"{v['size']}px", 'lineHeight': f"{v['line']}px", 'fontWeight': v['weight'], 'letterSpacing': f"{v['tracking']}px"}}
    for k, v in TYPE['scale'].items()}
dtcg['motion']['duration'] = {k: {'$type': 'duration', '$value': f'{v}ms'} for k, v in MOTION['duration'].items()}
dtcg['motion']['easing'] = {k: {'$type': 'cubicBezier', '$value': v} for k, v in MOTION['easing'].items()}
dtcg['motion']['spring'] = {k: {'$type': 'spring', '$value': v} for k, v in MOTION['spring'].items()}
dtcg['shadow'] = {k: {'$type': 'shadow', '$value': v} for k, v in SHADOW.items()}
with open(f'{OUT}/design-tokens.json', 'w') as f:
    json.dump(dtcg, f, indent=2)

# ---------------- 2) tokens.css ----------------
def cssvar(key): return '--' + key.replace('.', '-')
def kebab(s): return re.sub(r'(?<!^)(?=[A-Z])', '-', s).lower()
lines = ['/* Nayara fuel-loyalty design tokens — generated from design-tokens.json. Do not hand-edit. */',
         '/* Anchors from the Nayara Energy logo: navy #10447C · cyan #0080A0 · green #18945C · sky #249ADF */', '', ':root {']
for name, ramp in R.items():
    for s, v in ramp.items():
        lines.append(f'  --{name}-{s}: {v};')
lines.append('')
for key, (lv, _) in SEM.items():
    lines.append(f'  {cssvar(key)}: {lv};')
for key, (lv, _) in GRAD.items():
    lines.append(f'  --gradient-{kebab(key)}: {lv};')
for grp, d in DIM.items():
    for k, v in d.items():
        lines.append(f'  --{grp}-{kebab(k)}: {v}px;')
for k, v in MOTION['duration'].items():
    lines.append(f'  --duration-{k}: {v}ms;')
for k, v in MOTION['easing'].items():
    lines.append(f'  --easing-{k}: {v};')
for k, v in SHADOW.items():
    lines.append(f'  --shadow-{k}: {v};')
lines.append('}')
dark_block = ['  ' + f'{cssvar(k)}: {dv};' for k, (_, dv) in SEM.items()]
dark_block += ['  ' + f'--gradient-{kebab(k)}: {dv};' for k, (_, dv) in GRAD.items()]
dark_block += ['  --shadow-e1: none; --shadow-e2: none; --shadow-e3: none;',
               '  --shadow-e4: 0 16px 32px -8px rgba(0,0,0,0.55);']
lines += ['', '@media (prefers-color-scheme: dark) {', '  :root:not([data-theme="light"]) {'] + \
         ['  ' + l for l in dark_block] + ['  }', '}', '', '[data-theme="dark"] {'] + dark_block + ['}', '']
with open(f'{OUT}/tokens.css', 'w') as f:
    f.write('\n'.join(lines))

# ---------------- 3) NayaraColor.kt ----------------
def kcolor(hexv):
    if hexv.startswith('rgba'):
        r, g, b, a = re.match(r'rgba\((\d+),(\d+),(\d+),([\d.]+)\)', hexv.replace(' ', '')).groups()
        return f'Color({r}, {g}, {b}, {round(float(a)*255)})'
    return f'Color(0xFF{hexv[1:].upper()})'
def cap(s): return s[0].upper() + s[1:]
k = ['package com.acefuel.loyalty.ui.theme', '',
     'import androidx.compose.runtime.Immutable',
     'import androidx.compose.runtime.staticCompositionLocalOf',
     'import androidx.compose.ui.graphics.Color', '',
     '// ============================================================================',
     '// Nayara fuel-loyalty color tokens — GENERATED from docs/design/design-tokens.json',
     '// Brand anchors (pixel-verified from the official Nayara Energy logo):',
     '//   navy #10447C · cyan #0080A0 · green #18945C · sky #249ADF (nayaraenergy.com)',
     '// ============================================================================', '',
     'object NayaraPalette {']
for name, ramp in R.items():
    k.append(f'    // {name}')
    for s, v in ramp.items():
        k.append(f'    val {cap(name)}{s} = {kcolor(v)}')
k += [f'    val DarkCanvas = {kcolor(DS["canvas"])}',
      f'    val DarkSurface = {kcolor(DS["surface"])}',
      f'    val DarkRaised = {kcolor(DS["raised"])}',
      f'    val DarkOverlay = {kcolor(DS["overlay"])}',
      '    val White = Color(0xFFFFFFFF)', '    val Black = Color(0xFF000000)', '}', '',
      '/** Full semantic color set. Access via [LocalNayaraColors] / MaterialTheme wrapper. */',
      '@Immutable', 'data class NayaraColors(']
props = [key.replace('.', ' ').split() for key in SEM.keys()]
for grp, leaf in props:
    k.append(f'    val {grp}{cap(leaf)}: Color,')
k += [')', '']
for mode, idx in (('Light', 0), ('Dark', 1)):
    k.append(f'val Nayara{mode}Colors = NayaraColors(')
    for key, vals in SEM.items():
        grp, leaf = key.split('.')
        k.append(f'    {grp}{cap(leaf)} = {kcolor(vals[idx])},')
    k += [')', '']
k += ['val LocalNayaraColors = staticCompositionLocalOf { NayaraLightColors }', '']
with open(f'{OUT}/compose/NayaraColor.kt', 'w') as f:
    f.write('\n'.join(k))

print('emitted:', 'design-tokens.json', 'tokens.css', 'compose/NayaraColor.kt')
print('semantic tokens:', len(SEM), '| primitives:', sum(len(r) for r in R.values()) + 6)

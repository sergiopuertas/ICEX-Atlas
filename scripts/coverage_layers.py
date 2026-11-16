#!/usr/bin/env python3
"""Cobertura por capas (lcov de `flutter test --coverage`). Falla si domain o data < umbral.
Uso: python3 scripts/coverage_layers.py app/coverage/lcov.info 80"""
import collections
import sys

path, threshold = sys.argv[1], float(sys.argv[2] if len(sys.argv) > 2 else 80)
cov, f = collections.OrderedDict(), None
for line in open(path, encoding='utf-8'):
    if line.startswith('SF:'):
        f = line[3:].strip(); cov[f] = [0, 0]
    elif line.startswith('DA:'):
        hits = int(line.strip().split(',')[1]); cov[f][1] += 1; cov[f][0] += hits > 0


def layer(p):
    if p.endswith('.g.dart') or '/l10n/' in p:
        return None
    if '/domain/' in p:
        return 'domain'
    if '/data/' in p or 'core/api/' in p or 'core/db/' in p:
        return 'data'
    if '/application/' in p:
        return 'application'
    return 'presentation'


agg = collections.defaultdict(lambda: [0, 0])
for p, (h, t) in cov.items():
    if (lay := layer(p)):
        agg[lay][0] += h; agg[lay][1] += t
ok = True
for lay, (h, t) in sorted(agg.items()):
    pct = 100 * h / t if t else 100
    flag = ''
    if lay in ('domain', 'data') and pct < threshold:
        ok, flag = False, f'  ✗ < {threshold}%'
    print(f'{lay:13s} {h:5d}/{t:5d}  {pct:5.1f}%{flag}')
sys.exit(0 if ok else 1)

"""Extract the test vectors of mica-core docs/ble-provisioning.md into JSON.

Usage: python3 tools/extract_vectors.py <ble-provisioning.md> > test/protocol/vectors.json
"""
import json
import re
import sys

text = open(sys.argv[1], encoding='utf-8').read()
out = {}
for title, body in re.findall(r'^### (.+?)\n\n```\n(.*?)```', text.split('## Test vectors', 1)[1], re.S | re.M):
    section = {'pairs': [], 'lines': [], 'messages': []}
    for line in body.splitlines():
        if line.startswith('{'):
            section['messages'].append(json.loads(line))
        elif ' = ' in line:
            k, v = line.split(' = ', 1)
            v = json.loads(v) if v.startswith('"') or k == 'iterations' else v
            section['pairs'].append([k.strip(), v])
            section.setdefault(k.strip(), v)
        elif re.fullmatch(r'[0-9a-f]+', line):
            section['lines'].append(line)
    out[title] = section
json.dump(out, sys.stdout, indent=1)
print()

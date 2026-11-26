#!/usr/bin/env python3
"""Add 'when others => null;' to VHDL case statements that have no 'others' choice.

XST (ISE 14.7) wants 'others' when the choices are std_logic_vector values, even if all of
them are listed (Quartus accepts it). Applied in place to the imported SMS_MiSTer sources:

  src/tools/case_others.py FILE...

Each added line is marked "-- karabas". Idempotent: a case with 'others' is left as it is.
"""
import re
import sys

CASE = re.compile(r'^\s*case\b.*\bis\b', re.I)
END = re.compile(r'^\s*end\s+case\b', re.I)
OTHERS = re.compile(r'^\s*when\s+others\b', re.I)


def code(line):
    return line.split('--', 1)[0]


def fix(path):
    lines = open(path, encoding='latin-1').read().split('\n')
    stack = []  # [has_others] per open case
    out = []
    added = 0
    for line in lines:
        c = code(line)
        if END.match(c):
            if stack and not stack.pop():
                indent = re.match(r'\s*', line).group(0)
                out.append(indent + '\twhen others => null; -- karabas: XST needs others')
                added += 1
        elif CASE.match(c):
            stack.append(False)
        elif OTHERS.match(c) and stack:
            stack[-1] = True
        out.append(line)
    if added:
        open(path, 'w', encoding='latin-1').write('\n'.join(out))
    print(f'{path}: {added} case(s) got others')


for p in sys.argv[1:]:
    fix(p)

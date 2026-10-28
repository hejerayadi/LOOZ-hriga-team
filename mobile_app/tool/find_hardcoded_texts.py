"""Finds texts written directly in the Dart code (instead of lib/l10n/*.arb).

Run from mobile_app/:  python tool/find_hardcoded_texts.py
Every string with a letter (Latin or Arabic) in lib/ is listed, except the
technical ones that the user never sees (imports, asset paths, JSON keys,
language codes...). The result must be: 0 user-visible texts.
"""
import re
import sys
from pathlib import Path

# Latin and Arabic letters (not × and ÷).
LETTER = re.compile(r'[A-Za-zÀ-ÖØ-öø-ÿ؀-ۿ]')
STRING = re.compile(r"""(?<![A-Za-z0-9_])r?('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""")

# Technical strings: (name of the category, test on the line and the text).
TECHNICAL = [
    ('import / export', lambda line, s: re.match(r'\s*(import|export|part)\s', line) or 'dart.library' in line),
    ('asset path', lambda line, s: s.startswith(('assets/', 'photos/')) or s.endswith(('.svg', '.png', '.jpg', '.html'))),
    ('symbol file name', lambda line, s: re.match(r"\s*\w+\('[^']+', '\w+', \d+\)", line)),
    ('JSON / map key', lambda line, s: re.search(re.escape(f"'{s}'") + r"\s*:", line) or re.search(r"\[\s*'" + re.escape(s) + r"'\s*\]", line)),
    ('language code', lambda line, s: s in ('ar', 'fr')),
    ('3D page message', lambda line, s: s.startswith(('looz:', 'window.', '{"looz_lang"'))),
    ('data id / code', lambda line, s: re.fullmatch(r'(zone|node)-[a-z]|[A-D]|main|pollinizer|online|offline', s) is not None),
    ('font / channel name', lambda line, s: s in ('Cairo', 'LoozFlutter')),
    ('web (iframe) code', lambda line, s: s in ('iframe', 'message', 'none', 'window')),
    ('Supabase setting', lambda line, s: s.startswith('SUPABASE_') or s == 'YOUR-PROJECT' or ('supabase' in line.lower() and s in ('profiles', 'full_name', 'role', 'id'))),
]


def without_comment(line):
    """The line without its // comment (a // inside a string is kept)."""
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == '\\':
                i += 1
            elif c == quote:
                quote = None
        elif c in '\'"':
            quote = c
        elif line.startswith('//', i):
            return line[:i]
        i += 1
    return line


def main():
    root = Path(__file__).resolve().parent.parent / 'lib'
    counts, visible = {}, []
    for path in sorted(root.rglob('*.dart')):
        if 'l10n' in path.parts:
            continue  # generated from the .arb files
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            code = without_comment(line)
            for match in STRING.finditer(code):
                text = match.group(1)[1:-1]
                # Values put in the text ($name, ${...}) and ‏ are not letters.
                shown = re.sub(r'\$\{[^}]*\}?|\$\w+|\\u[0-9A-Fa-f]{4}', '', text)
                if not LETTER.search(shown):
                    continue
                for name, test in TECHNICAL:
                    if test(code, text):
                        counts[name] = counts.get(name, 0) + 1
                        break
                else:
                    visible.append(f'{path.relative_to(root.parent)}:{number}: {text}')
    print('Technical strings (not shown to the user):')
    for name, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f'  {n:4d}  {name}')
    print(f'\nUser-visible texts written in the code: {len(visible)}')
    for v in visible:
        print('  ' + v)
    return 1 if visible else 0


if __name__ == '__main__':
    sys.exit(main())

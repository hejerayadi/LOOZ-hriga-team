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

# The 24 governorates: codes saved in the database (profiles.zone), each shown
# with its Arabic / French name (lib/core/governorates.dart).
GOVERNORATE_CODES = {
    'tunis', 'ariana', 'ben_arous', 'manouba', 'nabeul', 'zaghouan', 'bizerte', 'beja',
    'jendouba', 'kef', 'siliana', 'sousse', 'monastir', 'mahdia', 'sfax', 'kairouan',
    'kasserine', 'sidi_bouzid', 'gabes', 'medenine', 'tataouine', 'gafsa', 'tozeur', 'kebili',
}

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
    ('regular expression (check of a name / phone)', lambda line, s: 'RegExp(' in line),
    ('governorate code (saved in the database, shown with its name)', lambda line, s: s in GOVERNORATE_CODES),
    ('key of a setting kept on the phone', lambda line, s: '_savedLanguageKey' in line),
    ('region code (shown with its Arabic / French name)', lambda line, s: re.match(r"\s*'[a-z_]+' => l10n\.region", line)),
    ('demo picture of the community', lambda line, s: s.startswith('demo:')),
    ('pack name of the database (migration 011)', lambda line, s: 'planFromName' in line or s in ('paid', 'essential', 'connected')),
]

# Files that only talk to Supabase (no screen): their strings are table and
# column names, error codes of the server and debug texts, never shown.
SERVER_FILES = {
    'data/auth_service.dart',
    'data/user_profile.dart',
    'data/community_service.dart',
    'data/community_photos.dart',  # file type, image_picker error codes, photo formats
    'data/community_models.dart',
    'data/payment_service.dart',  # tables, statuses and error codes of migrations 008 / 009 / 011
    'data/orchard_service.dart',  # tables and columns of the orchard (migration 011)
}
SERVER = 'Supabase names / error codes (lib/data/auth_service.dart, user_profile.dart, community_*.dart, payment_service.dart, orchard_service.dart)'


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
                if path.relative_to(root).as_posix() in SERVER_FILES:
                    counts[SERVER] = counts.get(SERVER, 0) + 1
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

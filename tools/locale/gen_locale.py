#!/usr/bin/env python3
"""Генерирует src/ReplicatedStorage/LocaleEn.lua и LocaleRu.lua из tools/locale/*.txt (единый источник ключей).
Формат строки: key | en | ru  (names.txt: english | ru). Строки с # — комментарии."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'src', 'ReplicatedStorage')

def esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')

def read(name, cols):
    rows = []
    for ln, line in enumerate(open(os.path.join(HERE, name), encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        parts = [p.strip() for p in line.split(' | ')]
        if len(parts) != cols:
            sys.exit(f'{name}:{ln}: expected {cols} columns: {line}')
        rows.append(parts)
    return rows

strings = read('server.txt', 3) + read('client.txt', 3)
seen = set()
for k, _, _ in strings:
    if k in seen:
        sys.exit(f'duplicate key {k}')
    seen.add(k)
names = read('names.txt', 2)

def write(path, header, var, idx, with_names):
    out = ['--!strict', f'-- {header}', '-- СГЕНЕРИРОВАНО tools/locale/gen_locale.py из tools/locale/*.txt — правьте исходники, не этот файл.',
           '-- Шаблоны: {name} — подстановка, {n|форма1|форма2|форма3} — плюрализация по числу n.', f'local {var} = {{}}', '', f'{var}.Strings = {{']
    for row in strings:
        out.append(f'\t["{esc(row[0])}"] = "{esc(row[idx])}",')
    out.append('}')
    out.append('')
    if with_names:
        out.append(f'-- Перевод «данных» (имена/описания из data-модулей), ключ — английский текст')
        out.append(f'{var}.Names = {{')
        for en, ru in names:
            out.append(f'\t["{esc(en)}"] = "{esc(ru)}",')
        out.append('}')
        out.append('')
    out.append(f'return {var}')
    open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')

write(os.path.join(OUT, 'LocaleEn.lua'), 'Строки интерфейса (английский — эталон набора ключей).', 'LocaleEn', 1, False)
write(os.path.join(OUT, 'LocaleRu.lua'), 'Строки интерфейса (русский).', 'LocaleRu', 2, True)
print(f'{len(strings)} keys, {len(names)} names')

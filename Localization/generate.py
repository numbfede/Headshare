"""Builds Resources/Localization/<lang>.lproj from keys.json + translations/<lang>.json.

translations/<lang>.json = {"bluetooth": "<NSBluetoothAlwaysUsageDescription>", "t": [one string per key, same order]}
Run: python3 Localization/generate.py
"""
import json, pathlib, re, shutil, sys

here = pathlib.Path(__file__).resolve().parent
out = here.parent / "Resources" / "Localization"
keys = json.loads((here / "keys.json").read_text())
EN_BLUETOOTH = "Headshare uses Bluetooth to list and connect your paired headphones and speakers."
# Regional variants that share a translation with their base language.
ALIASES = {"fr-CA": "fr", "es-419": "es", "zh-HK": "zh-Hant", "en-GB": "en", "en-AU": "en"}

def specs(s):
    return sorted(re.findall(r"%(?:\d\$)?(?:lld|@)", s))

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

def write(lang, strings, bluetooth):
    d = out / f"{lang}.lproj"
    d.mkdir(parents=True, exist_ok=True)
    lines = [f'"{esc(k)}" = "{esc(v)}";' for k, v in zip(keys, strings)]
    (d / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (d / "InfoPlist.strings").write_text(f'"NSBluetoothAlwaysUsageDescription" = "{esc(bluetooth)}";\n', encoding="utf-8")

if out.exists():
    shutil.rmtree(out)
errors = 0
langs = {"en": (keys, EN_BLUETOOTH)}
for f in sorted((here / "translations").glob("*.json")):
    data = json.loads(f.read_text(encoding="utf-8"))
    t = data["t"]
    if len(t) != len(keys):
        print(f"✗ {f.stem}: {len(t)} strings, expected {len(keys)}"); errors += 1; continue
    for i, (k, v) in enumerate(zip(keys, t)):
        if specs(k) != specs(v):
            print(f"✗ {f.stem}[{i}] placeholders differ: {k!r} -> {v!r}"); errors += 1
    langs[f.stem] = (t, data["bluetooth"])
if errors:
    sys.exit(f"{errors} problem(s), nothing written")
for lang, (t, bt) in langs.items():
    write(lang, t, bt)
for alias, base in ALIASES.items():
    if base in langs:
        write(alias, *langs[base])
print(f"✓ {len(langs) + sum(b in langs for b in ALIASES.values())} localizations written to {out}")

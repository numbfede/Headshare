"""Lists every user-facing string key in Sources/ (SwiftUI literals + String(localized:))."""
import re, pathlib, json, sys
root = pathlib.Path(__file__).resolve().parent.parent
STR = r'"((?:[^"\\]|\\.)*)"'
patterns = [
    r'String\(localized:\s*' + STR,
    r'\bText\(' + STR,
    r'\bButton\(' + STR,
    r'\bToggle\(' + STR,
    r'\bLabel\(' + STR,
    r'\bSection\(' + STR,
    r'\bLabeledContent\(' + STR,
    r'\bPicker\(' + STR,
    r'\bLink\(' + STR,
    r'\.help\(' + STR,
    r'SectionTitle\(title:\s*' + STR,
    r'Feature\(symbol:\s*"[^"]*",\s*title:\s*' + STR,
    r'Feature\(symbol:\s*"[^"]*",\s*title:\s*"[^"]*",\s*text:\s*' + STR,
    r'help:\s*' + STR,
]
# interpolations whose value is a String (-> %@); everything else is an integer (-> %lld)
STRING_INTERP = {"error.localizedDescription", "device.name", "v", "b"}
def to_key(lit):
    def rep(m):
        expr = m.group(1)
        return "%@" if expr in STRING_INTERP else "%lld"
    return re.sub(r'\\\(([^()]*(?:\([^()]*\))?[^()]*)\)', rep, lit).replace('\\"', '"')
keys = []
for f in sorted((root / "Sources").rglob("*.swift")):
    src = f.read_text()
    for pat in patterns:
        for m in re.finditer(pat, src):
            k = to_key(m.group(1))
            if k and k not in keys and not k.startswith(("headphones", "gear")):
                keys.append(k)
skip = {"Headshare", "", "GitHub"}
keys = [k for k in keys if k not in skip]
json.dump(keys, sys.stdout, ensure_ascii=False, indent=1)

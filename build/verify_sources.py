from pathlib import Path
import hashlib, json, sys, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
# Windows long path support for the retained BSP source tree.
if sys.platform == "win32" and not str(root).startswith(chr(92)*2+"?"):
    root = Path(chr(92)*2+"?"+chr(92)+str(root))
errors = []
items = json.loads((root/"build/source_manifest.json").read_text(encoding="utf8"))
for item in items:
    path = root/item["path"]
    if not path.is_file(): errors.append("missing: "+item["path"])
    elif hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
        errors.append("changed: "+item["path"])
tree = ET.parse(root/"mult_freq_jam_dma_0711.xpr")
refs = 0
for entry in tree.findall(".//FileSet/File"):
    value = entry.get("Path").replace("$PSRCDIR", "mult_freq_jam_dma_0711.srcs").replace("$PPRDIR/", "")
    refs += 1
    if not (root/value).is_file(): errors.append("XPR reference missing: "+value)
print("Checked", len(items), "manifest files and", refs, "direct XPR references")
for error in errors: print(error)
print("PASS" if not errors else "FAIL")
sys.exit(bool(errors))

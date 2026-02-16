import os
import re
import subprocess
import sys

index_path = sys.argv[1]
root_dir = os.path.dirname(os.path.abspath(index_path))

with open(index_path, "r", encoding="utf-8") as handle:
    content = handle.read()

links = re.findall(r"\[[^\]]+\]\(([^)]+)\)", content)
entries = []
for link in links:
    link = link.strip()
    if not link or link.startswith("mailto:"):
        continue
    base = link.split("#", 1)[0].strip()
    if not base:
        continue
    entries.append((link, base))

if not entries:
    print("No links found.")
    sys.exit(0)

failed = False
for original, base in entries:
    if re.match(r"^https?://", base):
        url = base
    else:
        url = "file://" + os.path.abspath(os.path.join(root_dir, base))

    result = subprocess.run(
        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url],
        capture_output=True,
        text=True,
        check=False,
    )
    code = result.stdout.strip()
    if code == "000":
        print(f"ERROR: {original} -> curl failed", file=sys.stderr)
        failed = True
    elif code.startswith("2") or code.startswith("3"):
        print(f"OK: {original} -> {code}")
    else:
        print(f"ERROR: {original} -> HTTP {code}", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)

print("All links OK.")

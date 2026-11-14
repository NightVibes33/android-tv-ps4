"""Host-only Wi-Fi handoff safety policy verification."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
source=(root/'runtime/opt/androidtv-ps4/autoboot.sh').read_text()
assert source==(root/'runtime/usr/sbin/androidtv-ps4-start').read_text()
assert 'for attempt in 1 2 3; do' in source
assert 'Wi-Fi phy transfer attempt $attempt failed' in source
assert 'Wi-Fi handoff: interface=$radio' in source
assert 'nsenter -t "$child" -n /usr/sbin/iw dev' in source
snippet=source[source.index("# Move the console's Wi-Fi radio"):source.index('echo "Android network attached',source.index("# Move the console's Wi-Fi radio"))]
assert 'rm -rf' not in snippet and 'rfkill unblock' not in snippet
subprocess.run(['sh','-n'],input=source,text=True,check=True)
print('PASS: bounded Wi-Fi handoff retry and logging; no data reset')

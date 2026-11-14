"""Exercise TV mode selection without modifying actual displays."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'runtime/opt/androidtv-ps4/resolution.sh').read_text()
function=source.split('# WindowManager is unavailable',1)[0]
with tempfile.TemporaryDirectory() as t:
    sysroot=Path(t)/'sys'
    drm=sysroot/'class/drm'
    drm.mkdir(parents=True)
    screen=drm/'card0-HDMI-A-1'
    screen.mkdir()
    (screen/'status').write_text('connected\n')
    cmd='set -eu\n'+function+'\natv_choose_resolution "$1"\n'
    subprocess.run(['sh','-n'],input=source,text=True,check=True)
    for modes,expected in [('1920x1080\n1280x720\n','1920x1080'),
                           ('1280x720\n','1280x720')]:
        (screen/'modes').write_text(modes)
        result=subprocess.run(['sh','-c',cmd,'probe',str(sysroot)],check=True,capture_output=True,text=True)
        assert result.stdout.strip()==expected,result.stdout
    (screen/'status').write_text('disconnected\n')
    result=subprocess.run(['sh','-c',cmd,'probe',str(sysroot)],capture_output=True,text=True)
    assert result.returncode!=0 and not result.stdout
print('PASS: 1080p chosen when supported, 720p fallback, unknown output not forced')

"""Firmware 14.00 source-port checks; never boots or modifies a PS4."""
from pathlib import Path
import re
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
magic=(root/'loader-source/linux/magic.h').read_text()
runner=(root/'source/boot-payload.c').read_text()
build=(root/'build-kexec.py').read_text()
header=root/'source/atv-fw-1400.h'
defines=re.findall(r'^#(?:if|elif) defined\s+(PS4_\d+_\d+)|^#ifdef\s+(PS4_\d+_\d+)',magic,re.M)
names=[x or y for x,y in defines]
assert len(names)==len(set(names))==21, names
assert names[-2:]==['PS4_13_52','PS4_14_00'],names[-3:]
assert 'PS4_14_02' not in names
expected={'kern_off_printf':'0x2E07C0','kern_off_kmem_free':'0x466710',
          'kern_off_pmap_protect':'0x58570','kern_off_gpu_devid_is_9924':'0x4AD0A0',
          'kern_off_eap_hdd_key':'0x26c4cf0','kern_off_edid':'0x275e148'}
block=magic.split('#elif defined PS4_14_00',1)[1].split('#endif',1)[0]
for key,value in expected.items():
    m=re.search(r'^#define '+key+r'\s+(0x[0-9a-fA-F]+)',block,re.M)
    assert m and int(m.group(1),16)==int(value,16),(key,m)
assert 'fwver==1400 && norm==1400' in runner
assert 'VAR(g_fw,void*)=(void*)&atv_fw_1400' in runner
assert '==21,defines' in build
# Prove the C ABI layout matches the 7-u64 fields of upstream fw_offsets_t.
with tempfile.TemporaryDirectory() as t:
    probe=Path(t)/'abi.c'
    probe.write_text('#include <assert.h>\n#include "'+str(header)+'"\n'+
                     'int main(void){const struct atv_fw_offsets *p=&atv_fw_1400;\n'+
                     'assert(p->fw_ver==1400 && p->xfast_syscall==0x1c0 && p->printf_off==0x2e07c0);\n'+
                     'assert(p->kmem_alloc==0x466540 && p->kernel_map==0x22d1d50);\n'+
                     'assert(p->patch1==0x46660c && p->patch2==0x466614 && p->pstate==0x3a2e40);return 0;}\n')
    exe=Path(t)/'abi'
    subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror',str(probe),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('PASS: 14.00 kexec source coverage and helper ABI; 14.02 fail-closed')

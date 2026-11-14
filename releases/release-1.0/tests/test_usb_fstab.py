"""Host test for the Android USB fstab writer; never touches real drives."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "runtime/opt/androidtv-ps4/autoboot.sh").read_text()
assert (root / "runtime/usr/sbin/androidtv-ps4-start").read_text() == source
start = source.index("# BEGIN atv-removable-usb-fstab")
end = source.index("# END atv-removable-usb-fstab", start)
function = source[start:end]

def fake_disk(sysroot, name, bus_path, internal=False):
    target = sysroot / "devices" / bus_path / "block" / name
    target.mkdir(parents=True)
    if internal: (target / f"{name}27").mkdir()
    (sysroot / "block").mkdir(exist_ok=True)
    (sysroot / "block" / name).symlink_to(target)

with tempfile.TemporaryDirectory() as tmp:
    d = Path(tmp)
    sysroot = d / "sys"
    fstab = d / "fstab.mustang"
    fake_disk(sysroot, "sda", "pci/usb1/1-1/host0/target0", True)
    fake_disk(sysroot, "sdb", "pci/usb2/2-1/host1/target1")
    fake_disk(sysroot, "sdc", "pci/usb3/3-2/host2/target2")
    fake_disk(sysroot, "sdd", "pci/ata1/host3/target3")
    shell = "set -eu\nstage() { :; }\n" + function + '\natv_write_removable_usb_fstab "$1" "$2"\n'
    subprocess.run(["sh", "-n"], input=shell, text=True, check=True)
    fstab.write_text("none /cache tmpfs defaults\n")
    subprocess.run(["sh", "-c", shell, "test", str(fstab), str(sysroot)], check=True)
    lines = fstab.read_text().splitlines()
    assert len(lines) == 3, lines
    assert "voldmanaged=usb0:auto" in lines[1], lines
    assert "voldmanaged=usb1:auto" in lines[2], lines
    assert "/usb2/" in lines[1] and "/usb3/" in lines[2], lines
    assert all("/usb1/" not in line for line in lines[1:]), lines
    assert all("/ata1/" not in line for line in lines[1:]), lines
    (sysroot / "block/sdb").unlink()
    (sysroot / "block/sdc").unlink()
    fstab.write_text("none /cache tmpfs defaults\n")
    subprocess.run(["sh", "-c", shell, "test", str(fstab), str(sysroot)], check=True)
    assert fstab.read_text().splitlines() == ["none /cache tmpfs defaults"]
print("PASS: preboot USB rules added; PS4 internal disk never exposed")

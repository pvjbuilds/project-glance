import os, pathlib, plistlib, shutil, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
 t=pathlib.Path(tmp); (t/'project/scripts').mkdir(parents=True);shutil.copy(root/'scripts/show.sh',t/'project/scripts/show.sh')
 app=t/'apps/Glance.app';(app/'Contents/Resources').mkdir(parents=True);(app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.projectoverview.viewer'}));(app/'Contents/Resources/GlanceInstallMarker').write_text('Glance local build\n')
 (t/'bin').mkdir(); fake=t/'bin/open'; fake.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$TEST_OUTPUT"\n');fake.chmod(0o755)
 env=os.environ.copy();env.update(GLANCE_INSTALL_DIR=str(t/'apps'),PATH=str(t/'bin')+':'+env['PATH'],TEST_OUTPUT=str(t/'called'))
 cmd=[str(t/'project/scripts/show.sh')];p=subprocess.run(cmd,env=env,capture_output=True);assert p.returncode==0,p.stderr;assert str(app) in (t/'called').read_text()
 (t/'called').unlink();(app/'Contents/Resources/GlanceInstallMarker').write_text('unknown');p=subprocess.run(cmd,env=env,capture_output=True);assert p.returncode!=0 and not (t/'called').exists()
 print('Installed launch without build and unknown-app refusal passed using fake open.')

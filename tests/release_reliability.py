import json, os, pathlib, plistlib, subprocess, tempfile, sys
base=pathlib.Path(__file__).resolve().parents[1]; binary=base/'build/glance-store'; installer=base/'scripts/install-agent-skills.sh'
with tempfile.TemporaryDirectory() as td:
 t=pathlib.Path(td); root=t/'data'; payload=t/'status.json';payload.write_text(json.dumps(dict(goal='Goal',checkpoint='Checkpoint',status='Active')))
 def run(*args): return subprocess.run([str(binary),'--store',str(root),*map(str,args)],capture_output=True)
 assert run('enroll','p','r','s',payload).returncode==0
 old=(root/'store.json').read_bytes(); assert run('update','p','s','1',payload).returncode==0
 assert (root/'store.backup.json').read_bytes()==old
 assert (root/'store.json').stat().st_mode & 0o777==0o600
 backup=(root/'store.backup.json').read_bytes(); good=(root/'store.json').read_bytes()
 for where,value in [('schema',True),('record_schema',True),('version',True),('version',-1),('version',1.5),('version',9223372036854775807)]:
  record=json.loads(good)
  if where=='schema': record['schema']=value
  elif where=='record_schema': record['projects']['p']['schema']=value
  else: record['projects']['p']['version']=value
  bad=json.dumps(record).encode(); (root/'store.json').write_bytes(bad)
  assert run('update','p','s','2',payload).returncode!=0
  assert (root/'store.json').read_bytes()==bad and (root/'store.backup.json').read_bytes()==backup
 corrupted=b'{broken\n';(root/'store.json').write_bytes(corrupted)
 assert run('update','p','s','2',payload).returncode!=0
 assert (root/'store.json').read_bytes()==corrupted and (root/'store.backup.json').read_bytes()==backup
 (root/'store.json').unlink(); assert run('enroll','new','r2','s2',payload).returncode!=0
 assert not (root/'store.json').exists() and (root/'store.backup.json').read_bytes()==backup
 app=t/'Glance.app'; (app/'Contents/Resources').mkdir(parents=True);(app/'Contents/MacOS').mkdir()
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.projectoverview.viewer','CFBundleShortVersionString':'0.1.0'})); (app/'Contents/Resources/AgentGuide.md').write_text('test'); u=app/'Contents/MacOS/glance-store';u.write_text('#!/bin/sh\n');u.chmod(0o755)
 only=t/'only-agents'; untouched=t/'untouched-claude'
 onlyargs=[str(installer),'--codex-only','--app',str(app),'--codex-home',str(only),'--claude-home',str(untouched)]
 assert subprocess.run(onlyargs,capture_output=True).returncode==0 and not untouched.exists()
 (only/'skills/project-glance/SKILL.md').write_text('unmanaged')
 assert subprocess.run(onlyargs,capture_output=True).returncode!=0 and not untouched.exists()
 ch=t/'agents';cl=t/'claude'; args=[str(installer),'--app',str(app),'--codex-home',str(ch),'--claude-home',str(cl)]
 def install(): return subprocess.run(args,capture_output=True,text=True)
 v=install(); assert v.returncode==0,(v.stdout,v.stderr)
 assert subprocess.run([sys.executable,'/Users/praj/.codex/skills/.system/skill-creator/scripts/quick_validate.py',str(ch/'skills/project-glance')],capture_output=True).returncode==0
 first=(ch/'skills/project-glance/SKILL.md').read_bytes(); assert install().returncode==0 and (ch/'skills/project-glance/SKILL.md').read_bytes()==first
 (cl/'skills/project-glance/SKILL.md').write_text('unmanaged')
 before=(ch/'skills/project-glance/SKILL.md').read_bytes();assert install().returncode!=0 and (ch/'skills/project-glance/SKILL.md').read_bytes()==before
 print('Passed: backup bytes, corruption and missing-primary preservation, 0600 mode, idempotent install, unmanaged rejection and all-target preflight.')

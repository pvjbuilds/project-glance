#!/bin/sh
set -eu
exec /usr/bin/python3 - "$@" <<'PY'
import argparse, hashlib, os, pathlib, plistlib, stat, tempfile
p=argparse.ArgumentParser(description='Install derived Glance skill routers')
p.add_argument('--codex-only',action='store_true',help='Install only the Codex router; do not inspect the Claude home')
p.add_argument('--codex-home',default=os.path.expanduser('~/.agents'))
p.add_argument('--claude-home',default=os.path.expanduser('~/.claude'))
p.add_argument('--app',default=os.path.expanduser('~/Applications/Glance.app'))
a=p.parse_args()
app=pathlib.Path(a.app).expanduser().absolute()
guide=app/'Contents/Resources/AgentGuide.md'; updater=app/'Contents/MacOS/glance-store'
try:
 with (app/'Contents/Info.plist').open('rb') as f: info=plistlib.load(f)
 if info.get('CFBundleIdentifier')!='local.projectoverview.viewer' or not info.get('CFBundleShortVersionString') or not guide.is_file() or not updater.is_file() or not os.access(updater,os.X_OK): raise ValueError('wrong app identity or missing guide/updater')
except (OSError,ValueError,plistlib.InvalidFileException) as e: raise SystemExit(f'App validation failed: {e}')
# JSON-style quoting is valid YAML and safely represents arbitrary absolute paths.
import json
body=('---\nname: project-glance\ndescription: Use when asked to add this to Glance, send this to Glance, explicitly connect a chat, or update an already associated project.\n---\n\n# Project Glance\n\n'
      'This router is derived from Glance '+str(info['CFBundleShortVersionString'])+'; installed guide SHA-256: '+hashlib.sha256(guide.read_bytes()).hexdigest()+'. Do not maintain competing workflow rules here. '
      'Read the installed guide at '+json.dumps(str(guide),ensure_ascii=False)+' and use the updater at '+json.dumps(str(updater),ensure_ascii=False)+'. '
      'Follow its explicit enrollment, session association, version and readback rules. Never discover projects or import transcripts.\n')
marker='# Glance managed router sha256: '
def render(b): return (b+marker+hashlib.sha256(b.encode()).hexdigest()+'\n').encode()
def managed(data):
 try:
  rest,separator,digest=data.decode().rpartition(marker)
  return bool(separator) and digest.strip()==hashlib.sha256(rest.encode()).hexdigest() and rest.startswith('---\nname: project-glance\n')
 except (UnicodeError,ValueError): return False

def reject_symlinks(path):
 for x in (path,*path.parents):
  if x.is_symlink() and str(x) not in ('/var','/tmp'): raise SystemExit('Refusing symlink path: '+str(x))

targets=[pathlib.Path(a.codex_home).expanduser().absolute()/'skills/project-glance']
if not a.codex_only: targets.append(pathlib.Path(a.claude_home).expanduser().absolute()/'skills/project-glance')
if len(targets)==2 and targets[0]==targets[1]: raise SystemExit('Skill homes must be different')
for target in targets:
 reject_symlinks(target)
 if target.exists():
  if not target.is_dir(): raise SystemExit('Refusing non-directory: '+str(target))
  entries=list(target.iterdir())
  if any(e.name!='SKILL.md' or e.is_symlink() or not e.is_file() for e in entries): raise SystemExit('Refusing unknown files: '+str(target))
  if entries and not managed(entries[0].read_bytes()): raise SystemExit('Refusing unmanaged skill: '+str(target))
  if not entries: raise SystemExit('Refusing existing unmanaged empty directory: '+str(target))
for target in targets:
 target.mkdir(parents=True,exist_ok=True,mode=0o700)
 data=render(body); dest=target/'SKILL.md'
 if dest.exists() and dest.read_bytes()==data: print('unchanged:',dest); continue
 fd,tmp=tempfile.mkstemp(prefix='.glance-',dir=target)
 try:
  with os.fdopen(fd,'wb') as f: f.write(data); f.flush(); os.fsync(f.fileno())
  os.replace(tmp,dest)
 finally:
  if os.path.exists(tmp): os.unlink(tmp)
 print('installed:',dest)
PY

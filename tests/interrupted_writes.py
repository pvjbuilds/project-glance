#!/usr/bin/env python3
"""Kill isolated, instrumented writers at save boundaries. Never modifies production source."""
import json, os, pathlib, signal, subprocess, tempfile, time
base=pathlib.Path(__file__).resolve().parents[1]
source=(base/'Sources/Store.swift').read_text()
# Injection exists only in a disposable test build. Stop after lock, tempfile sync,
# backup commit, and primary rename, before the corresponding next operation.
hook='''\nfunc testStop(_ point: String) {\n    if ProcessInfo.processInfo.environment["GLANCE_TEST_STOP"] == point { raise(SIGSTOP) }\n}\n'''
source=source.replace('struct StoreError:', hook+'\nstruct StoreError:',1)
source=source.replace('guard rename(temp, url.path) == 0', 'if url.lastPathComponent == "store.json" { testStop("temp-synced") }\n    guard rename(temp, url.path) == 0',1)
source=source.replace('    let dfd = open(dir.path, O_RDONLY)', '    if url.lastPathComponent == "store.json" { testStop("primary-renamed") }\n    let dfd = open(dir.path, O_RDONLY)',1)
source=source.replace('        try durableReplace(prior, url.deletingLastPathComponent().appendingPathComponent("store.backup.json"))','        try durableReplace(prior, url.deletingLastPathComponent().appendingPathComponent("store.backup.json"))\n        testStop("backup-committed")',1)
source=source.replace('    let storeURL = root.appendingPathComponent("store.json")', '    testStop("locked")\n    let storeURL = root.appendingPathComponent("store.json")',1)
with tempfile.TemporaryDirectory(prefix='glance-interrupt-') as td:
 t=pathlib.Path(td); src=t/'Store.swift'; src.write_text(source); binary=t/'glance-store'; cache=t/'cache';cache.mkdir()
 env=os.environ.copy();env['CLANG_MODULE_CACHE_PATH']=str(cache)
 subprocess.run(['swiftc','-module-cache-path',str(cache),str(src),'-o',str(binary)],env=env,check=True)
 for stage in ('locked','temp-synced','backup-committed','primary-renamed'):
  for iteration in range(3):
   root=t/(stage+str(iteration)); payload=t/'payload.json'
   def call(*args,env=None):
    return subprocess.run([str(binary),'--store',str(root),*map(str,args)],env=env,capture_output=True,timeout=10)
   def setpayload(label): payload.write_text(json.dumps({'goal':'Goal','checkpoint':label,'status':'Active'}))
   setpayload('first'); assert call('enroll','p','r','s',payload).returncode==0
   setpayload('second'); assert call('update','p','s','1',payload).returncode==0
   old=json.loads((root/'store.json').read_bytes()); setpayload('third')
   e=os.environ.copy();e['GLANCE_TEST_STOP']=stage
   proc=subprocess.Popen([str(binary),'--store',str(root),'update','p','s','2',str(payload)],env=e,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
   deadline=time.monotonic()+10
   while time.monotonic()<deadline:
    pid,status=os.waitpid(proc.pid,os.WUNTRACED|os.WNOHANG)
    if pid:
     assert os.WIFSTOPPED(status),(stage,status)
     break
    time.sleep(.01)
   else:
    proc.kill();proc.wait();raise AssertionError('writer did not reach '+stage)
   os.kill(proc.pid,signal.SIGKILL);proc.wait(timeout=5)
   current=json.loads((root/'store.json').read_bytes()); backup=json.loads((root/'store.backup.json').read_bytes())
   assert current['projects']['p']['version'] in (2,3)
   assert current['projects']['p']['status']['checkpoint'] in ('second','third')
   assert backup['projects']['p']['version'] in (1,2)
   assert current['projects']['p']['version']==(3 if stage=='primary-renamed' else 2)
   listed=call('list');assert listed.returncode==0,(stage,listed.stderr)
   version=json.loads(listed.stdout)['projects']['p']['version']
   setpayload('after interruption'); result=call('update','p','s',version,payload)
   assert result.returncode==0,(stage,result.stderr)
   assert json.loads(call('list').stdout)['projects']['p']['version']==version+1
  print(stage+': 3 SIGKILL trials passed')
print('12 interrupted writers: valid primary and backup, lock released, subsequent update succeeded. No power-loss simulation.')

#!/usr/bin/env python3
"""Kill disposable instrumented recovery writers at four boundaries."""
import hashlib, json, os, pathlib, signal, subprocess, tempfile, time
base = pathlib.Path(__file__).resolve().parents[1]
src = (base/'Sources/Store.swift').read_text()
src = src.replace('struct StoreError:', 'func testStop(_ point: String) { if ProcessInfo.processInfo.environment["GLANCE_RECOVERY_STOP"] == point { raise(SIGSTOP) } }\nstruct StoreError:', 1)
src = src.replace('            try durableReplace(primaryData, archive)', '            testStop("before-archive")\n            try durableReplace(primaryData, archive)\n            testStop("after-archive")', 1)
src = src.replace('        try durableReplace(bytes, storeURL)', '        testStop("before-primary")\n        try durableReplace(bytes, storeURL)', 1)
src = src.replace('    let dfd = open(dir.path, O_RDONLY)', '    if url.lastPathComponent == "store.json" { testStop("after-primary") }\n    let dfd = open(dir.path, O_RDONLY)', 1)
with tempfile.TemporaryDirectory(prefix='glance-recovery-') as td:
    temp=pathlib.Path(td); source=temp/'Store.swift'; source.write_text(src); binary=temp/'store'; cache=temp/'cache'; cache.mkdir()
    subprocess.run(['swiftc','-module-cache-path',str(cache),str(source),'-o',str(binary)],check=True)
    for stage in ('before-archive','after-archive','before-primary','after-primary'):
        root=temp/stage; payload=temp/'payload.json'; payload.write_text(json.dumps({'goal':'Goal','checkpoint':'One','status':'Active'}))
        def call(*args): return subprocess.run([str(binary),'--store',str(root),*map(str,args)],capture_output=True,text=True,timeout=10)
        assert call('enroll','p','r','s',payload).returncode == 0
        assert call('migrate').returncode == 0
        project=json.loads(call('list').stdout)['projects']['p']; token=project['updateToken']
        assert call('update','p','s',token,payload).returncode == 0
        backup=root/'store.backup.json'; old_backup=backup.read_bytes(); primary=root/'store.json'; corrupt=b'{corrupt'; primary.write_bytes(corrupt)
        digest=lambda data:hashlib.sha256(data).hexdigest()
        env=os.environ.copy(); env['GLANCE_RECOVERY_STOP']=stage
        proc=subprocess.Popen([str(binary),'--store',str(root),'recover',digest(old_backup),digest(corrupt),'accept-data-loss'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            pid,status=os.waitpid(proc.pid,os.WUNTRACED|os.WNOHANG)
            if pid:
                assert os.WIFSTOPPED(status),(stage,status)
                break
            time.sleep(.01)
        else: proc.kill(); proc.wait(); raise AssertionError('recovery did not reach '+stage)
        os.kill(proc.pid,signal.SIGKILL); proc.wait(timeout=5)
        assert backup.read_bytes()==old_backup
        archives=list(root.glob('store.corrupt.*.json'))
        if stage != 'before-archive': assert any(p.read_bytes()==corrupt for p in archives)
        if stage != 'after-primary':
            assert primary.read_bytes()==corrupt
            assert call('recover',digest(old_backup),digest(corrupt),'accept-data-loss').returncode == 0
        else: assert any(p.read_bytes()==corrupt for p in archives)
        recovered=json.loads(call('list').stdout)['projects']['p']
        assert call('update','p','s',token,payload).returncode != 0
        assert call('update','p','s',recovered['updateToken'],payload).returncode == 0
        print(stage+': interrupted recovery preserved data and remained recoverable')
print('Four isolated recovery interruptions passed; no power-loss simulation.')

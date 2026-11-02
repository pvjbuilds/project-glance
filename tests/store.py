#!/usr/bin/env python3
import json, pathlib, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor
binary = pathlib.Path(__file__).resolve().parents[1] / 'build/glance-store'
with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp) / 'data'
    payload = pathlib.Path(tmp) / 'payload.json'
    payload.write_text(json.dumps({'goal':'Demo goal', 'checkpoint':'Demo checkpoint', 'status':'Active'}))
    def call(*args, ok=True):
        p = subprocess.run([str(binary), '--store', str(root), *map(str,args)], capture_output=True, text=True)
        assert (p.returncode == 0) == ok, (args,p.stdout,p.stderr)
        return p
    call('list',ok=False)
    assert not root.exists()
    call('enroll','demo','request1','session1',payload)
    call('enroll','demo','request1','session1',payload)
    call('enroll','demo','request2','session1',payload,ok=False)
    call('update','demo','unknown','1',payload,ok=False)
    call('update','demo','session1','0',payload,ok=False)
    call('connect','demo','session2')
    def update(_): return subprocess.run([str(binary),'--store',str(root),'update','demo','session2','2',str(payload)],capture_output=True).returncode
    with ThreadPoolExecutor(max_workers=8) as pool: results=list(pool.map(update,range(8)))
    assert results.count(0)==1 and len(results)==8, results
    call('enroll','../escape','request','session',payload,ok=False)
    current = json.loads(call('list').stdout)['projects']['demo']
    assert current['version'] == 3 and current['status'] == json.loads(payload.read_text())
    bad = pathlib.Path(tmp) / 'bad.json'
    bad.write_text(json.dumps({'goal':'only'}))
    call('update','demo','session2','3',bad,ok=False)
    call('enroll','other','request1','session1',payload,ok=False)
    store = json.loads((root/'store.json').read_text())
    store['projects']['demo']['sessions'] = 'malformed'
    (root/'store.json').write_text(json.dumps(store))
    call('connect','demo','session3',ok=False)
    (root/'store.json').write_text('{')
    call('list',ok=False)
print('Store checks passed: explicit enrollment, retry, authorization, revisions, concurrency, path safety, missing and malformed data.')

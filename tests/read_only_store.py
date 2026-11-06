#!/usr/bin/env python3
"""Public CLI contract when the store directory is readable but not writable."""
import json, os, pathlib, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor

if os.geteuid() == 0:
    raise SystemExit('This permission test requires a non-root user; root can bypass file modes')

binary = pathlib.Path(__file__).resolve().parents[1] / 'build/glance-store'
with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp) / 'data'
    payload = pathlib.Path(tmp) / 'payload.json'
    payload.write_text(json.dumps({'goal': 'Goal', 'checkpoint': 'Checkpoint', 'status': 'Active'}))
    def call(*args):
        cmd = [str(binary), '--store', str(root), *map(str, args)]
        return subprocess.run(cmd, capture_output=True, text=True)
    assert call('enroll', 'demo', 'req', 'session', payload).returncode == 0
    (root / '.lock').chmod(0o400)
    root.chmod(0o500)
    before = (root / 'store.json').read_bytes()
    result = call('list')
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert json.loads(result.stdout)['projects']['demo']['version'] == 1
    denied_enroll = call('enroll', 'other', 'req2', 'session', payload)
    assert denied_enroll.returncode != 0 and 'host permission grant' in denied_enroll.stderr
    assert 'uncertain' not in denied_enroll.stderr and (root / 'store.json').read_bytes() == before
    assert not (root / 'store.backup.json').exists()
    denied = call('update', 'demo', 'session', '1', payload)
    assert denied.returncode != 0 and 'host permission grant' in denied.stderr, denied.stderr
    assert 'uncertain' not in denied.stderr and (root / 'store.json').read_bytes() == before
    root.chmod(0o700)
    (root / '.lock').unlink()
    root.chmod(0o500)
    assert call('list').returncode == 0
    assert not (root / '.lock').exists()
    root.chmod(0o700)
    bad = call('list', 'extra')
    assert bad.returncode != 0 and 'uncertain' not in bad.stderr
    (root / 'store.json').write_text('{')
    assert call('list').returncode != 0
    (root / 'store.json').write_text(json.dumps({'schema': 99, 'projects': {}}))
    assert call('list').returncode != 0
    (root / 'store.json').unlink()
    (root / 'store.backup.json').write_bytes(before)
    assert call('list').returncode != 0
    assert not (root / 'store.json').exists() and not (root / '.lock').exists()
    (root / 'store.json').write_bytes(before)
    assert call('migrate').returncode == 0
    listed = json.loads(call('list').stdout)['projects']['demo']
    assert listed['updateToken'].endswith(':1')
    def writer():
        for _ in range(30):
            record = json.loads(call('list').stdout)['projects']['demo']
            result = call('update', 'demo', 'session', record['updateToken'], payload)
            assert result.returncode == 0, result.stderr
    def reader():
        for _ in range(100):
            result = call('list')
            assert result.returncode == 0, result.stderr
            record = json.loads(result.stdout)['projects']['demo']
            assert record['updateToken'].endswith(':' + str(record['version']))
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(writer), pool.submit(reader), pool.submit(reader)]
        for future in futures: future.result()
    assert json.loads(call('list').stdout)['projects']['demo']['version'] == 31
print('Read-only store checks passed')

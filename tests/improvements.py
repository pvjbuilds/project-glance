#!/usr/bin/env python3
"""Behavioral checks through the public updater and readback interface."""
import json, pathlib, subprocess, tempfile
binary = pathlib.Path(__file__).resolve().parents[1] / 'build/glance-store'
with tempfile.TemporaryDirectory() as td:
    root = pathlib.Path(td) / 'store'; payload = pathlib.Path(td) / 'status.json'
    def run(*args):
        return subprocess.run([str(binary), '--store', str(root), *map(str, args)], capture_output=True, text=True)
    base = {'goal':'Goal', 'checkpoint':'Release', 'status':'Active'}
    payload.write_text(json.dumps(base)); assert run('enroll','p','r','s',payload).returncode == 0
    # A checkpoint cannot claim completion without its finish condition and evidence.
    invalid = dict(base, checkpointClosure={'state':'complete','finishCondition':'Passed review'})
    payload.write_text(json.dumps(invalid)); result = run('update','p','s','1',payload)
    assert result.returncode != 0, 'Incomplete checkpoint closure was accepted'
    invalid = dict(base, effortRange={'min':8,'max':3,'unit':'hours','source':'Estimate','coverage':'Current checkpoint'})
    payload.write_text(json.dumps(invalid)); result = run('update','p','s','1',payload)
    assert result.returncode != 0, 'Reversed effort range was accepted'
    invalid = dict(base, recurring={'current':'November','source':''})
    payload.write_text(json.dumps(invalid)); result = run('update','p','s','1',payload)
    assert result.returncode != 0, 'Recurring cycle without source was accepted'
    migrated = run('migrate')
    assert migrated.returncode == 0, 'Explicit migration to generation-aware revisions failed: ' + migrated.stderr
    project = json.loads(run('list').stdout)['projects']['p']
    assert project.get('updateToken'), 'List did not return a copyable update token'
    old_token = project['updateToken']
    payload.write_text(json.dumps(base)); assert run('update','p','s',old_token,payload).returncode == 0
    import hashlib
    backup = root / 'store.backup.json'; primary = root / 'store.json'
    primary.write_text('{broken')
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    recovered = run('recover',digest(backup),digest(primary),'accept-data-loss')
    assert recovered.returncode == 0, 'Explicit recovery failed: ' + recovered.stderr
    archives = list(root.glob('store.corrupt.*.json'))
    assert len(archives) == 1 and archives[0].read_text() == '{broken'
    assert archives[0].stat().st_mode & 0o777 == 0o600
    restored = json.loads(run('list').stdout)['projects']['p']
    assert run('update','p','s',old_token,payload).returncode != 0, 'Old generation accepted after recovery'
    assert run('update','p','s',str(restored['version']),payload).returncode != 0, 'Numeric revision accepted after recovery'
    assert run('update','p','s',restored['updateToken'],payload).returncode == 0
    current = json.loads(run('list').stdout)['projects']['p']
    primary.unlink()
    missing = run('recover',digest(backup),'missing','accept-data-loss')
    assert missing.returncode == 0, 'Missing primary recovery failed: ' + missing.stderr
    recovered_project = json.loads(run('list').stdout)['projects']['p']
    mismatch = run('recover','0'*64,digest(primary),'accept-data-loss')
    assert mismatch.returncode != 0, 'Recovery accepted wrong backup digest'
    healthy = run('recover',digest(backup),digest(primary),'accept-data-loss')
    assert healthy.returncode != 0, 'Recovery replaced a healthy primary'
    assert json.loads(run('list').stdout)['projects']['p']['updateToken'] == recovered_project['updateToken']
    # Optional structured values round-trip together through update and list.
    project = json.loads(run('list').stdout)['projects']['p']
    valid = dict(base, checkpointClosure={'state':'complete','finishCondition':'Pass review','evidence':'Review passed'}, effortRange={'min':2,'max':4,'unit':'hours','source':'Prior work','coverage':'Current checkpoint'}, recurring={'current':'November','last':'October complete','next':'December','source':'User'})
    payload.write_text(json.dumps(valid)); assert run('update','p','s',project['updateToken'],payload).returncode == 0
    assert json.loads(run('list').stdout)['projects']['p']['status'] == valid
    project = json.loads(run('list').stdout)['projects']['p']
    invalid = dict(valid, externalWait={'reason':'Waiting for review','source':''})
    payload.write_text(json.dumps(invalid)); assert run('update','p','s',project['updateToken'],payload).returncode != 0, 'External wait without source was accepted'
    project = json.loads(run('list').stdout)['projects']['p']; old_token = project['updateToken']
    assert run('connect','p','s2').returncode == 0
    connected = json.loads(run('list').stdout)['projects']['p']
    assert connected['updateToken'].split(':')[0] == old_token.split(':')[0] and connected['status'] == project['status']
    payload.write_text(json.dumps(base)); assert run('update','p','s',old_token,payload).returncode != 0
    assert run('update','p','s',connected['updateToken'],payload).returncode == 0

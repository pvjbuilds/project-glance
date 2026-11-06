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
    valid = {'goal':'Goal','checkpoint':'Checkpoint','status':'Active','checklist':[{'id':'one','title':'Done milestone','done':True},{'id':'two','title':'Open milestone','done':False}]}
    payload.write_text(json.dumps(valid)); call('update','demo','session2','3',payload)
    current=json.loads(call('list').stdout)['projects']['demo']; assert current['version']==4 and current['status']['checklist']==valid['checklist']
    for bad in ([{'id':'one','title':'Missing done'}], [{'id':'one','title':'Not boolean','done':1}], [{'id':'one','title':'Not boolean','done':'true'}], [{'id':'one','title':'A','done':True},{'id':'one','title':'B','done':False}], 'invalid'):
        valid['checklist']=bad; payload.write_text(json.dumps(valid)); call('update','demo','session2','4',payload,ok=False)
    assert json.loads(call('list').stdout)['projects']['demo']['version']==4
    nested = {'goal':'Goal','checkpoint':'Checkpoint','status':'Active','currentMilestoneID':'child', 'tokenUsage':{'estimate':240000,'scope':'linked-chat','source':'Example','coverage':'Linked chat only'}, 'checklist':[{'id':'parent','title':'Parent','done':False,'children':[{'id':'child','title':'Child','done':False},{'id':'complete','title':'Done','done':True,'tokenUsage':{'estimate':1000,'source':'Example','coverage':'Single task'}}]}]}
    payload.write_text(json.dumps(nested)); call('update','demo','session2','4',payload)
    stored=json.loads(call('list').stdout)['projects']['demo']; assert stored['version']==5 and stored['status']==nested
    def reject(obj):
        payload.write_text(json.dumps(obj)); call('update','demo','session2','5',payload,ok=False)
    import copy
    for value in [True, -1, 1.5, '12', None]:
        bad=copy.deepcopy(nested); bad['tokenUsage']['estimate']=value; reject(bad)
    for field in ('source','coverage'):
        bad=copy.deepcopy(nested); bad['tokenUsage'][field]=' '; reject(bad)
    bad=copy.deepcopy(nested); bad['tokenUsage']['scope']='task'; reject(bad)
    bad=copy.deepcopy(nested); bad['checklist'][0]['children'][1]['tokenUsage']['scope']='linked-chat'; reject(bad)
    bad=copy.deepcopy(nested); bad['currentMilestoneID']='complete'; reject(bad)
    bad=copy.deepcopy(nested); bad['currentMilestoneID']='missing'; reject(bad)
    bad=copy.deepcopy(nested); bad['checklist'][0]['done']=True; reject(bad)
    bad=copy.deepcopy(nested); bad['checklist'][0]['children'][0]['id']='parent'; reject(bad)
    bad=copy.deepcopy(nested); bad['checklist'][0]['children']='invalid'; reject(bad)
    bad=copy.deepcopy(nested); x=bad['checklist'][0]['children'][0]; x['children']=[{'id':'c','title':'C','done':False,'children':[{'id':'d','title':'D','done':False,'children':[{'id':'e','title':'E','done':False}]}]}]; reject(bad)
    bad=copy.deepcopy(nested); bad['checklist']=[{'id':'i'+str(i),'title':'item','done':False} for i in range(201)]; bad.pop('currentMilestoneID'); reject(bad)
    assert json.loads(call('list').stdout)['projects']['demo']['version']==5
    for state in ('moving','waiting-on-you','blocked','parked','needs-scoping','checkpoint-complete'):
        health = copy.deepcopy(nested); health['health'] = {'state':state,'reason':'Explicitly recorded reason'}
        payload.write_text(json.dumps(health))
        version = json.loads(call('list').stdout)['projects']['demo']['version']
        result = call('update','demo','session2',str(version),payload)
        assert f'updated: demo version {version+1}' in result.stdout
        saved = json.loads(call('list').stdout)['projects']['demo']
        assert saved['status']['health'] == health['health'] and saved['updatedBySession'] == 'session2'
    version = saved['version']
    before_connect = saved.copy()
    call('connect','demo','session3')
    saved = json.loads(call('list').stdout)['projects']['demo']; version = saved['version']
    assert saved['updatedAt'] == before_connect['updatedAt'] and saved['updatedBySession'] == before_connect['updatedBySession']
    for invalid in (None, {}, {'state':'unknown','reason':'why'}, {'state':'parked','reason':' '}, {'state':'parked','reason':'x'*2001}):
        invalid_payload = copy.deepcopy(nested); invalid_payload['health'] = invalid
        payload.write_text(json.dumps(invalid_payload)); call('update','demo','session2',str(version),payload,ok=False)
    assert json.loads(call('list').stdout)['projects']['demo']['version'] == version
    # Older records remain valid without either optional field.
    legacy = json.loads((root/'store.json').read_text()); legacy['projects']['demo'].pop('updatedBySession'); legacy['projects']['demo']['status'].pop('health')
    (root/'store.json').write_text(json.dumps(legacy)); call('list')
    invalid_updater = copy.deepcopy(legacy); invalid_updater['projects']['demo']['updatedBySession']='unassociated'
    (root/'store.json').write_text(json.dumps(invalid_updater)); call('list',ok=False)
    (root/'store.json').write_text(json.dumps(legacy))
    store = json.loads((root/'store.json').read_text())
    store['projects']['demo']['sessions'] = 'malformed'
    (root/'store.json').write_text(json.dumps(store))
    call('connect','demo','session3',ok=False)
    (root/'store.json').write_text('{')
    call('list',ok=False)
print('Store checks passed: explicit enrollment, retry, authorization, revisions, concurrency, path safety, missing and malformed data.')

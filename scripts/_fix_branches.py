import json, ssl, urllib.request
ADMIN = '5e4e9a7fabdee48cae2df0f476707fa075394fe54673904fc28156df7be7a843'
BASE = 'https://192.168.10.238:8444/api/v4'
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE

def getj(p):
    r = urllib.request.Request(BASE+p, headers={'Authorization':'Bearer '+ADMIN})
    return json.loads(urllib.request.urlopen(r, context=ctx).read())

def put_file(branch, content, msg):
    body = json.dumps({'branch':branch,'content':content,'encoding':'text','commit_message':msg}).encode()
    req = urllib.request.Request(BASE+'/projects/2/repository/files/.gitlab-ci.yml', data=body,
            headers={'Authorization':'Bearer '+ADMIN,'Content-Type':'application/json'}, method='PUT')
    return json.loads(urllib.request.urlopen(req, context=ctx).read())

print('== GitLab branches ==')
for b in getj('/projects/2/repository/branches'):
    print(' ', b['name'], b['commit']['short_id'])

# find my test commit on main and its parent (original content)
commits = getj('/projects/2/repository/commits?ref_name=main')
parent = None
for c in commits:
    if 'k3s 5-node deploy via k3s-cluster5-runner' in (c.get('title','')+c.get('message','')):
        parent = c['parent_ids'][0]
        break
if not parent and len(commits) > 1:
    parent = commits[1]['id']
print('reverting main to parent commit', parent)
orig = getj('/projects/2/repository/files/.gitlab-ci.yml?ref=%s'%parent)
orig_content = orig['content']  # base64
# decode base64
import base64
text = base64.b64decode(orig_content).decode('utf-8')
print('original main CI length', len(text))
put_file('main', text, 'revert: restore original main CI (test change undone)')
print('main reverted')

# cancel test pipeline 209
try:
    req = urllib.request.Request(BASE+'/projects/2/pipelines/209/cancel', headers={'Authorization':'Bearer '+ADMIN}, method='POST')
    print('pipeline 209 cancel status:', json.loads(urllib.request.urlopen(req, context=ctx).read()).get('status'))
except Exception as e:
    print('cancel 209 error:', e)

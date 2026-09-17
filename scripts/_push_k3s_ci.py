import json, ssl, urllib.request
ADMIN = '5e4e9a7fabdee48cae2df0f476707fa075394fe54673904fc28156df7be7a843'
BASE = 'https://192.168.10.238:8444/api/v4'
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
content = open('/tmp/ci_k3s.yml').read()
body = json.dumps({'branch':'k3s-cluster5','content':content,'encoding':'text',
                   'commit_message':'ci: k3s 5-node deploy via k3s-cluster5-runner (apply from k3s-cluster5)'}).encode()
req = urllib.request.Request(BASE+'/projects/2/repository/files/.gitlab-ci.yml', data=body,
        headers={'Authorization':'Bearer '+ADMIN,'Content-Type':'application/json'}, method='PUT')
try:
    print('push CI resp:', urllib.request.urlopen(req, context=ctx).read().decode()[:150])
except Exception as e:
    print('push CI error:', e); raise
# trigger pipeline on k3s-cluster5
req2 = urllib.request.Request(BASE+'/projects/2/pipeline?ref=k3s-cluster5', headers={'Authorization':'Bearer '+ADMIN}, method='POST')
d = json.loads(urllib.request.urlopen(req2, context=ctx).read())
open('/tmp/last_pipeline.txt','w').write(str(d.get('id')))
print('pipeline', d.get('id'), 'status', d.get('status'))

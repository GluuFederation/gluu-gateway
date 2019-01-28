from flask import Flask, jsonify, request, render_template

import requests
import os
import json

requests.packages.urllib3.disable_warnings()

app = Flask(__name__)


gg_proxy_url = "http://gg.mygluu.org:8000"
oxd_host = "https://gg.mygluu.org:8443"
op_host = "https://op.mygluu.org"
api_path = "posts"

# Kong route register with below host
host_without_claims = "none-claim-gatering.mygluu.org"
host_with_claims = "claim-gatering.mygluu.org"


# Consumer client
client_oxd_id = "ff07da07-76a8-4f01-8d25-78cd5f11cd3c"
client_id = "@!014E.16BD.1411.4CE7!0001!A63E.5899!0008!6FBF.27B7.507C.44AD"
client_secret = "1dd53b7f-1ce2-4351-8581-918b96cb678d"

# You need to add this URL in your consumer client in OP
claims_redirect_url = "https://rs.mygluu.org:5500/cg"


def get_ticket(host):
    request_url = os.path.join(gg_proxy_url, api_path)
    response = requests.get(request_url, headers={"Host": host} )
    
    ticket = ''
    if "WWW-Authenticate" in response.headers:
        n_eq = response.headers["WWW-Authenticate"].rfind('=')
        ticket = response.headers["WWW-Authenticate"][n_eq+1:].strip('"')
    
    return {'response': response, 
            'title': "Client calls GG Proxy API without RPT token", 
            'ticket': ticket,
            }

def get_permission_access_token():
    request_url = os.path.join(oxd_host, 'get-client-token')
    body = {"client_id": client_id,
            "client_secret": client_secret,
            "op_host": op_host,
            "scope": ["oxd", "openid"]
            }
            
    response = requests.post(request_url,
                             headers={"Content-Type": "application/json"},
                             json=body,
                             verify=False)

    return {'response': response, 
            'title': "Authenticating client in oxd-server",
            }
    

def get_rpt(access_token, ticket):
    request_url = os.path.join(oxd_host, 'uma-rp-get-rpt')
    body = {"oxd_id": client_oxd_id,
            "ticket": ticket
            }
    
    
    response = requests.post(request_url,
                             headers={"Content-Type": "application/json",
                                      "Authorization": "Bearer " + access_token
                                      },
                             json=body,
                             verify=False)

    token = ''
    redirect_url = ''
    
    js_data = response.json()

    if 'redirect_user' in js_data:
        redirect_url = js_data['redirect_user']
    else:
        token = js_data['access_token']
        
    
    return {'response': response, 
            'title': "Client calls AS UMA /token endpoint with permission ticket and client credentials",
            'token': token,
            'redirect_url': redirect_url
            }


def call_gg_rpt(host, rpt):
    request_url = os.path.join(gg_proxy_url, api_path)
    response = requests.get(request_url,
                            headers={'Host': host, 
                                     'Authorization': 'Bearer {0}'.format(rpt),
                                     }
                            )
                            
    return {'response': response, 
            'title': "Client calls GG Proxy API with RPT token.",
            }
                


@app.route('/<ct>', methods=['GET','POST'])
def index(ct):
    
    steps = []
    
    if ct == 'cg':
        host = host_with_claims
    else:
       host = host_without_claims
    
    if not 'ticket' in request.args:
        result1 = get_ticket(host)
        ticket = result1['ticket']
        steps.append(result1)
    else:
        ticket = request.args['ticket']

    result2 = get_permission_access_token()
    access_token = result2['response'].json()['access_token']
    steps.append(result2)

    result3 = get_rpt(access_token, ticket)
    steps.append(result3)

    if result3['token']:
        result4 = call_gg_rpt(host, result3['token'])
        steps.append(result4)

    claim_redirectUrl = ''
    if  result3['redirect_url']:
        claim_redirectUrl = "{0}&claims_redirect_uri={1}".format(result3['redirect_url'], claims_redirect_url)

    return render_template('index.html', steps=steps, claim_redirectUrl=claim_redirectUrl)


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5500, debug=True, ssl_context='adhoc')

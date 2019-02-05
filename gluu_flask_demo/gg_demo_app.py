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
host_without_claims = "non-claim-gathering.mygluu.org"
host_with_claims = "claim-gathering.mygluu.org"


# Consumer client
client_oxd_id = "545f701e-e617-4d6d-96fb-3b04785f8deb"
client_id = "@!014E.16BD.1411.4CE7!0001!A63E.5899!0008!7A2E.9642.7246.715A"
client_secret = "e19a90a4-1829-4be6-865d-30213df07f5d"

# You need to add this URL in your consumer client in OP
claims_redirect_url = "https://rs.mygluu.org:5500/cg"


def get_ticket(host):
    request_url = os.path.join(gg_proxy_url, api_path)
    response = requests.get(request_url, headers={"Host": host} )
    error = None
    ticket = ''
    if "WWW-Authenticate" in response.headers:
        try:
            n_eq = response.headers["WWW-Authenticate"].rfind('=')
            ticket = response.headers["WWW-Authenticate"][n_eq+1:].strip('"')
        except:
            pass
    
    if not ticket:
        error =  "Can't obtain ticket"
        
    return {'response': response, 
            'title': "Client calls GG Proxy API without RPT token", 
            'ticket': ticket,
            'error': error,
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
    error = None
    access_token = ''

    try:
        access_token = response.json()['access_token']
    except:
        error = "Cant obtain access token"
    

    return {'response': response, 
            'title': "Authenticating client in oxd-server",
            'access_token': access_token,
            'error': error,
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
    
    error = None
    
    try:
        js_data = response.json()
    except:
        error = "Server did not return valid json data"
        js_data = {}

    if 'redirect_user' in js_data:
        redirect_url = js_data['redirect_user']
    else:
        if 'access_token' in js_data:
            token = js_data['access_token']
        else:
            error = "Can't obtain access token"
        
    
    return {'response': response, 
            'title': "Client calls AS UMA /token endpoint with permission ticket and client credentials",
            'token': token,
            'redirect_url': redirect_url,
            'error': error,
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
    
    # Determine which host to be used
    if ct == 'cg':
        host = host_with_claims
    else:
        host = host_without_claims
    
    
    # Client calls API without RPT token
    if not 'ticket' in request.args:
        result1 = get_ticket(host)
        ticket = result1['ticket']
        steps.append(result1)
    else:
        # Here is my PCT token!
        # Client attempts to get RPT at UMA /token endpoint, this time presenting the PCT
        ticket = request.args['ticket']

    # Get Permission access token
    result2 = get_permission_access_token()
    access_token = result2['access_token']
    steps.append(result2)

    # Client calls AS UMA /token endpoint with permission ticket and client credentials
    result3 = get_rpt(access_token, ticket)
    steps.append(result3)

    # Client calls API Gateway with RPT token
    if result3['token']:
        result4 = call_gg_rpt(host, result3['token'])
        steps.append(result4)

    # No RPT for you!  Go directly to Claims Gathering!
    # AS returns needs_info with claims gathering URI, which the user should
    # put in his browser. Link shorter would be nice if the user has to type it in.
    claim_redirectUrl = ''
    if  result3['redirect_url']:
        claim_redirectUrl = "{0}&claims_redirect_uri={1}".format(result3['redirect_url'], claims_redirect_url)

    return render_template('index.html', steps=steps, claim_redirectUrl=claim_redirectUrl)


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5500, debug=True, ssl_context='adhoc')

import requests
from display import *
from config import *

def callAPIwithoutRPT (url, host):
    response = requests.get(url, headers={"Host": host})
    displayActionName("1. Client calls API without RPT token")
    displayResponse(response,"")
    return response.headers["WWW-Authenticate"].split(",")[3].split("=")[1].replace("\"", "")

def callAPIwithRPT (url, host, rpt):
    response = requests.get(url, headers={"Host": host, "Authorization":"Bearer "+rpt})
    displayActionName("4. Client calls API with RPT token. RPT="+rpt)
    displayResponse(response,"")

def callOxdToGetClientAccessToken(url):
    body={"oxd_id": client_oxd_id,
          "client_id": client_id,
          "client_secret": client_secret,
          "op_host": ce_url,
          "scope": ["uma_protection","openid"]}
    response = requests.post(url,
                             headers={"Content-Type": "application/json"},
                             json=body,
                             verify=False)
    displayActionName("2. Authenticating client in oxd-server")
    displayResponse(response,body)
    return response.json()['data']['access_token']


def callOxdToGetRpt(access_token, ticket, url, scope):
    body={"oxd_id": client_oxd_id,
          "ticket": ticket,
          "scope": [scope,"uma_protection"]}
    response = requests.post(url,
                             headers={"Content-Type": "application/json",
                                      "Authorization": "Bearer " + access_token},
                             json=body,
                             verify=False)
    displayActionName("3. Client calls AS UMA /token endpoint with permission ticket and client creds")
    displayResponse(response,body)
    if(response.json()['status'] == "error"):
        return True,"", response.json()['data']['details']['redirect_user']
    else :
        return False,response.json()['data']['access_token'],""

def createClaimsUrl(redirect_url, claims_redirect_url):
    return redirect_url+"&claims_redirect_uri="+claims_redirect_url

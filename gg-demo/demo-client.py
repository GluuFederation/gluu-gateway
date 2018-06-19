#!/usr/bin/python

import requests
import cgi
import cgitb; cgitb.enable()

print "HTTP/1.0 200 OK"
print "Content-type: text/html\n\n"
print ""

api_url="https://kong.example.com/demo/protected1"
gg_base_url = "http://demo.gluu.org"
oxd_host = "https://demo.gluu.org"
ce_url="https://demo.gluu.org"
api_path = "posts"

host_with_claims="gathering.example.com"
host_without_claims="non-gathering.example.com"
host=""

client_oxd_id="a5c511db-bbec-4d06-a046-b5feef7658a8"
client_id="@!7A1F.7A69.7E9A.EFBA!0001!AD32.2532!0008!893E.3C4C.D852.8BB5"
client_secret="ea5c3f6a-58f4-4aba-bead-4b36f0c0f520"

claims_redirect_url="http://demo.gluu.org:8080/cgi-bin/demo-client.cgi"



def callAPIwithoutRPT (url, host):
    response = requests.get(url, headers={"Host": host})
    print "Client calls API without RPT token</br>"
    print url
    print "Response status: "+str(response.status_code)+"</br>"
    print "Response headers: "+str(response.headers)+"</br>"
    return response.headers["WWW-Authenticate"].split(",")[3].split("=")[1].replace("\"", "")

def callAPIwithRPT (url, host, rpt):
    response = requests.get(url, headers={"Host": host, "Authorization":"Bearer "+rpt})
    print "Client calls API with RPT token"+"</br>"
    print url+"</br>"
    print "Response body: </br>"+str(response.json())+"</br>"

def callOxdToGetClientAccessToken(url):
    print "Authenticating client in oxd-server"
    response = requests.post(url,
                             headers={"Content-Type": "application/json"},
                             json={"oxd_id": client_oxd_id,
                                   "client_id": client_id,
                                   "client_secret": client_secret,
                                   "op_host": ce_url,
                                   "scope": ["uma_protection","openid"]},
                             verify=False)
    return response.json()['data']['access_token']


def callOxdToGetRpt(access_token, ticket, url, scope):
    print "Client calls AS UMA /token endpoint with permission ticket and client creds"
    response = requests.post(url,
                             headers={"Content-Type": "application/json",
                                      "Authorization": "Bearer " + access_token},
                             json={"oxd_id": client_oxd_id,
                                   "ticket": ticket,
                                   "scope": [scope,"uma_protection"]},
                             verify=False)
    if(response.json()['status'] == "error"):
        return True,"", response.json()['data']['details']['redirect_user']
    else :
        return False,response.json()['data']['access_token'],""

def isTicketInUrl():
    arguments = cgi.FieldStorage()
    return 'ticket' in arguments

def isClaimInUrl():
    arguments = cgi.FieldStorage()
    if('claim' in arguments):
        return host_with_claims, "demo_scope_gathering"
    else:
        return host_without_claims, "demo_scope_non_gathering"









host,scope = isClaimInUrl()

if(isTicketInUrl()):
    arguments = cgi.FieldStorage()
    ticket = arguments['ticket'].value
    access_token = callOxdToGetClientAccessToken(url=oxd_host + ":8443/get-client-token")

    # Here is my PCT token!
    # Client attempts to get RPT at UMA /token endpoint, this time presenting the
    # PCT
    need_info, token, redirect_url = callOxdToGetRpt(access_token, ticket, url=oxd_host + ":8443/uma-rp-get-rpt",scope="demo_scope_gathering")
    print "</br>RPT: "+token+"</br>"
    callAPIwithRPT(url=gg_base_url + ":8000/" + api_path, host=host_with_claims, rpt=token)
    quit()

# Client calls API without RPT token
ticket = callAPIwithoutRPT( url=gg_base_url+":8000/"+api_path, host=host)

#Authenticate client in oxd-server
access_token = callOxdToGetClientAccessToken(url = oxd_host + ":8443/get-client-token")

# Client calls AS UMA /token endpoint with permission ticket and client creds
need_info,token,redirect_url = callOxdToGetRpt(access_token, ticket, url = oxd_host + ":8443/uma-rp-get-rpt",scope = scope)

# Client calls API Gateway with RPT token
if(not need_info):
    callAPIwithRPT(url=gg_base_url+":8000/"+api_path, host=host, rpt=token)

# No RPT for you!  Go directly to Claims Gathering!
# AS returns needs_info with clailms gathering URI, which the user should
# put in his browser. Link shortner would be nice if the user has to type it in.
if(need_info):
    fullClaimRedirectUrl = redirect_url+"&claims_redirect_uri="+claims_redirect_url
    print "</br><a href="+fullClaimRedirectUrl+">"+fullClaimRedirectUrl+"</a></br>"



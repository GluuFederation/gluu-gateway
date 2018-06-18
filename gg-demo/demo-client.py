#!/usr/bin/python

import requests
from oxdpython import Client

config = "demo-py-oxd.cfg"
client = Client(config)
client.get_client_token()


init=False
api_url="https://kong.example.com/demo/protected1"
gg_base_url = "http://demo.gluu.org"
api_path = "posts"
host="demo22.example.com"

# Client calls API without RPT token
response= requests.get(gg_base_url+":8000/"+api_path ,headers={"Host":host})
print response.headers
ticket=response.headers["WWW-Authenticate"].split(",")[3].split("=")[1].replace("\"", "")

# Client calls AS UMA /token endpoint with permission ticket and client creds
rpt = client.uma_rp_get_rpt(ticket)
print rpt

# Client calls API Gateway with RPT token
response= requests.get(gg_base_url+":8000/"+api_path,headers={"Host":host, "Authorization": 'Bearer {}'.format(rpt)})
print response.json()

# No RPT for you!  Go directly to Claims Gathering!
# AS returns needs_info with clailms gathering URI, which the user should
# put in his browser. Link shortner would be nice if the user has to type it in.
claims_url = client.uma_rp_get_claims_gathering_url(ticket)
print "<a href="+claims_url+">"+claims_url+"</a>"

# Here is my PCT token!
# Client attempts to get RPT at UMA /token endpoint, this time presenting the
# PCT
rpt = client.uma_rp_get_rpt(ticket)
print rpt
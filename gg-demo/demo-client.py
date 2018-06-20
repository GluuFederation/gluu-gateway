#!/usr/bin/python
import cgitb; cgitb.enable()
from calls import *
from config import *


def handleClaimsGatheringResponse():
    if (isTicketInUrl()):
        arguments = cgi.FieldStorage()
        ticket = arguments['ticket'].value
        access_token = callOxdToGetClientAccessToken(url=oxd_host + ":8443/get-client-token")

        # Here is my PCT token!
        # Client attempts to get RPT at UMA /token endpoint, this time presenting the PCT
        displayActionName(" Client attempts to get RPT at UMA /token endpoint, this time presenting the PCT")
        need_info, token, redirect_url = callOxdToGetRpt(access_token, ticket, url=oxd_host + ":8443/uma-rp-get-rpt",
                                                         scope="demo_scope_gathering")
        callAPIwithRPT(url=gg_base_url + ":8000/" + api_path, host=host_with_claims, rpt=token)
        quit()


displayPageHeader()
host,scope = isClaimInUrl()
handleClaimsGatheringResponse()


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
    fullClaimRedirectUrl = createClaimsUrl(redirect_url,claims_redirect_url)
    displayActionName("4. Claims gathering url")
    displayPanel("<a href="+fullClaimRedirectUrl+">"+fullClaimRedirectUrl+"</a>")
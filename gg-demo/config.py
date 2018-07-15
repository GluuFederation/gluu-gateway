import cgi

gg_base_url = "http://demo.gluu.org"
oxd_host = "https://demo.gluu.org"
ce_url="https://demo.gluu.org"
api_path = "posts"

host_with_claims="gathering.example.com"
host_without_claims="non-gathering.example.com"

client_oxd_id=""
client_id=""
client_secret=""

claims_redirect_url="http://demo.gluu.org:8080/cgi-bin/demo-client.cgi"


def isTicketInUrl():
    arguments = cgi.FieldStorage()
    return 'ticket' in arguments

def isClaimInUrl():
    arguments = cgi.FieldStorage()
    if('claim' in arguments):
        return host_with_claims, "demo_scope_gathering"
    else:
        return host_without_claims, "demo_scope_non_gathering"

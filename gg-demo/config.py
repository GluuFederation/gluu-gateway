import cgi

gg_base_url = "http://demo.gluu.org"
oxd_host = "https://demo.gluu.org"
ce_url="https://demo.gluu.org"
api_path = "posts"

host_with_claims="gathering.example.com"
host_without_claims="non-gathering.example.com"

client_oxd_id="b7581ab4-8d79-4726-b122-77c0169e0a11"
client_id="@!7A1F.7A69.7E9A.EFBA!0001!AD32.2532!0008!5245.0911.0853.050A"
client_secret="09e59ea4-b74a-4796-8972-71e6c0af0a41"

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
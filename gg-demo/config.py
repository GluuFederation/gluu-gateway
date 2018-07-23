import cgi

gg_base_url = "http://demo.gluu.org"                # GG url, which listens to 8000 port
oxd_host = "https://demo.gluu.org"                  # Url of your oxd server, which is listening to 8443 port
ce_url="https://demo.gluu.org"                      # Url of yout Gluu-server instance (oxAuth)
api_path = "posts"                                  # Api path used in demo

host_with_claims="gathering.example.com"            # Host which is secured with demo_scope_gathering in GG. This scope needs to have UMA policy, which needs claims gathering
host_without_claims="non-gathering.example.com"     # Host which is secured with demo_scope_non_gathering in GG. This scope needs to have UMA policy, which return true

client_oxd_id=""                                    # Client oxd id of consumer configured in GG with UMA mode
client_id=""                                        # Client id of consumer configured in GG with UMA mode
client_secret=""                                    # Client secret of consumer configured in GG with UMA mode

claims_redirect_url="http://demo.gluu.org:8080/cgi-bin/demo-client.cgi" # This is a uri which is used after the claims gathering.  This uri also has to be set in client configuration in gluu-server (OpenID Connect -> Clients -> your client -> Add Claim Redirect Uris).


def isTicketInUrl():
    arguments = cgi.FieldStorage()
    return 'ticket' in arguments

def isClaimInUrl():
    arguments = cgi.FieldStorage()
    if('claim' in arguments):
        return host_with_claims, "demo_scope_gathering"
    else:
        return host_without_claims, "demo_scope_non_gathering"

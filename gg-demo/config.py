import cgi

gg_admin_url = "http://gluu.local.org:8001"
gg_proxy_url = "http://gluu.local.org:8000"
oxd_host = "https://gluu.local.org:8553"
ce_url = "https://gluu.local.org"
api_path = "posts/1"

# Kong route register with below host
host_with_claims = "gathering.example.com"
host_without_claims = "non-gathering.example.com"

# Consumer client
client_oxd_id = "91b14554-17ac-4cf4-917d-f1b27e95902a"
client_id = "@!FBA4.9EDD.24E7.909F!0001!64E0.493A!0008!BE4C.B4F6.E5CC.DB74"
client_secret = "1b3e24c2-5472-4c26-a33f-b0b1c0c2b1c3"

# You need to add this URL in your consumer client in CE
claims_redirect_url = "https://gluu.local.org/cgi-bin/index.py"


def is_ticket_in_url():
    arguments = cgi.FieldStorage()
    return 'ticket' in arguments


def is_claim_in_url():
    arguments = cgi.FieldStorage()
    if 'claim' in arguments or 'ticket' in arguments:
        return host_with_claims
    else:
        return host_without_claims

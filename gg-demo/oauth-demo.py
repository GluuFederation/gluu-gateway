import requests
import json

oxd_server_url = "https://dev1.gluu.org:8443"
consumer_client_id = "f0117a26-8c34-46cd-a53f-51f1a2ba50b1"
consumer_client_secret = "82121e1d-c485-41af-859e-f4de3c7d0632"
kong_proxy_url = "https://dev1.gluu.org"
kong_route_host = "oauth-demo.example.com"
op_server = "https://ce-dev6.gluu.org"

def http_post_call(endpoint, payload):
    response = None
    try:
        response = requests.post(endpoint, data=json.dumps(payload), headers={'content-type': 'application/json'},  verify=False)
        response_json = json.loads(response.text)

        if response.ok:
            return response_json
        else:
            message = """Error: Failed Not Ok Endpoint: %s 
                Payload %s
                Response %s 
                Response_Json %s
                Please check logs.""" % (endpoint, payload, response, response_json)
            print(message)
    except requests.exceptions.HTTPError as e:
        message = """Error: Failed Http Error:
                Endpoint: %s 
                Payload %s
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, payload, response, e)
        print(message)
    except requests.exceptions.ConnectionError as e:
        message = """Error: Failed to Connect:
                Endpoint: %s 
                Payload %s
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, payload, response, e)
        print(message)
    except requests.exceptions.RequestException as e:
        message = """Error: Failed Something Else:
                Endpoint %s 
                Payload %s
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, payload, response, e)
        print(message)

def http_get_call(endpoint, headers):
    response = None
    try:
        response = requests.get(endpoint, headers=headers, verify=False)

        if response.ok:
            return response.text
        else:
            message = """Error: Failed Not Ok Endpoint: %s 
                Response %s 
                Please check logs.""" % (endpoint, response.text)
            print(message)

    except requests.exceptions.HTTPError as e:
        message = """Error: Failed Http Error:
                Endpoint: %s 
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, response, e)
        self.exit(message)
    except requests.exceptions.ConnectionError as e:
        message = """Error: Failed to Connect:
                Endpoint: %s 
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, response, e)
        self.exit(message)
    except requests.exceptions.RequestException as e:
        message = """Error: Failed Something Else:
                Endpoint %s 
                Response %s
                Error %s 
                Please check logs.""" % (endpoint, response, e)
        self.exit(message)

token_payload = {
    'client_id': consumer_client_id,
    'client_secret': consumer_client_secret,
    'op_host': op_server,
    'scope': ['read']
}

token_response = http_post_call("%s/get-client-token" % oxd_server_url, token_payload)
print "--------- Token Response ---------- \n"
print token_response

resource_access_response = http_get_call(("%s/posts/1" % kong_proxy_url), {'content-type': 'application/json', 'authorization': ('bearer %s' % token_response['access_token']), 'Host': kong_route_host})
print "--------- Requested resource response ---------- \n"
print resource_access_response

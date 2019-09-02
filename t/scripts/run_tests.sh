#!/bin/bash

DISTRIBUTION=$1

# Install JQ for JSON parse in test case
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
cp jq /usr/bin

# Init
HOST=$2
OP_HOST=$3
OXD_HOST='localhost'
KONG_PROXY_HOST=$2
KONG_ADMIN_HOST='localhost'
OXD_PORT=8443

function test_oauth_auth_and_pep() {
    # Create service in kong
    SERVICE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/services/  -H 'Content-Type: application/json'  -d '{"name":"jsonplaceholder","url":"https://jsonplaceholder.typicode.com"}'`

    SERVICE_ID=`echo $SERVICE_RESPONSE | jq -r ".id"`
    echo "SERVICE_ID " .. $SERVICE_ID

    ROUTE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/routes/ -H 'Content-Type: application/json' -d '{"hosts": ["jsonplaceholder.typicode.com"],"service": {"id": "'$SERVICE_ID'"}}'`

    ROUTE_ID=`echo $ROUTE_RESPONSE | jq -r ".id"`
    echo "ROUTE_ID " .. $ROUTE_ID

    # Create OP Client for OAuth plugin

    OP_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/register-site  -H "Content-Type: application/json" -d  '{"client_name":"test_oauth_pep","access_token_as_jwt":true,"rpt_as_jwt":true,"access_token_signing_alg":"RS256", "op_host":"https://'$OP_HOST'", "redirect_uris": ["https://client.example.com/cb"], "grant_types":["client_credentials"]}'`

    OXD_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".oxd_id"`
    CLIENT_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".client_id"`
    CLIENT_SECRET=`echo $OP_CLIENT_RESPONSE | jq -r ".client_secret"`
    echo "OXD_ID " .. $OXD_ID
    echo "CLIENT_ID " .. $CLIENT_ID
    echo "CLIENT_SECRET " .. $CLIENT_SECRET

    # Config plugins
    ## OAUTH-AUTH
    OAUTH_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins/  -H 'Content-Type: application/json'  -d '{"name":"gluu-oauth-auth","config":{"oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","op_url":"https://'$OP_HOST'","oxd_id":"'$OXD_ID'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","pass_credentials":"pass"},"service_id":"'$SERVICE_ID'"}'`

    OAUTH_PLUGIN_ID=`echo $OAUTH_PLUGIN_RESPONSE | jq -r ".id"`
    echo $OAUTH_PLUGIN_RESPONSE
    echo "OAUTH_AUTH_PLUGIN_ID " .. $OAUTH_PLUGIN_ID

    ## OAUTH-PEP
    OAUTH_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins/  -H 'Content-Type: application/json'  -d '{"name":"gluu-oauth-pep","config":{"method_path_tree":{"POST":{"posts":{"??":{"#":{"path":"/posts/??","scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["oxd","openid"]}}}},"comments":{"??":{"#":{"path":"/comments/??","scope_expression":{"rule":{"and":[{"var":0}]},"data":["oxd"]}}}}},"DELETE":{"posts":{"??":{"#":{"path":"/posts/??","scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["oxd","openid"]}}}},"comments":{"??":{"#":{"path":"/comments/??","scope_expression":{"rule":{"and":[{"var":0}]},"data":["oxd"]}}}}},"PUT":{"posts":{"??":{"#":{"path":"/posts/??","scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["oxd","openid"]}}}},"comments":{"??":{"#":{"path":"/comments/??","scope_expression":{"rule":{"and":[{"var":0}]},"data":["oxd"]}}}}},"GET":{"posts":{"??":{"#":{"path":"/posts/??","scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["oxd","openid"]}}}},"comments":{"??":{"#":{"path":"/comments/??","scope_expression":{"rule":{"and":[{"var":0}]},"data":["oxd"]}}}}}},"client_id":"'$CLIENT_ID'","oauth_scope_expression":[{"path":"/posts/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["oxd","openid"]}}]},{"path":"/comments/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0}]},"data":["oxd"]}}]}],"op_url":"https://'$OP_HOST'","deny_by_default":true,"oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","client_secret":"'$CLIENT_SECRET'","oxd_id":"'$OXD_ID'"},"service_id":"'$SERVICE_ID'"}'`

    OAUTH_PLUGIN_ID=`echo $OAUTH_PLUGIN_RESPONSE | jq -r ".id"`
    echo "OAUTH_PEP_PLUGIN_ID " .. $OAUTH_PLUGIN_ID

    # Create OP Client for Consumer

    OP_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/register-site  -H "Content-Type: application/json" -d  '{"client_name":"test_oauth_pep","access_token_as_jwt":true,"rpt_as_jwt":true,"access_token_signing_alg":"RS256", "op_host":"https://'$OP_HOST'", "redirect_uris": ["https://client.example.com/cb"], "grant_types":["client_credentials"], "scope": ["openid", "oxd", "uma_protection"]}'`

    CONSUMER_OXD_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".oxd_id"`
    CONSUMER_CLIENT_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".client_id"`
    CONSUMER_CLIENT_SECRET=`echo $OP_CLIENT_RESPONSE | jq -r ".client_secret"`
    echo "OXD_ID " .. $CONSUMER_OXD_ID
    echo "CLIENT_ID " .. $CONSUMER_CLIENT_ID
    echo "CLIENT_SECRET " .. $CONSUMER_CLIENT_SECRET


    # Create kong consumer
    CONSUMER_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/consumers/  -H 'Content-Type: application/json'  -d '{"username":"cons_jsonplaceholder","custom_id":"'$CONSUMER_CLIENT_ID'"}'`

    CONSUMER_ID=`echo $CONSUMER_RESPONSE | jq -r ".id"`
    echo "CONSUMER_ID " .. $CONSUMER_ID


    # OAUTH
    RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/get-client-token -H "Content-Type: application/json" -d '{"client_id":"'$CONSUMER_CLIENT_ID'","client_secret":"'$CONSUMER_CLIENT_SECRET'","op_host":"'$OP_HOST'", "scope":["openid", "oxd", "uma_protection"]}'`

    TOKEN=`echo $RESPONSE | jq -r ".access_token"`
    echo "Access Token " .. $TOKEN


    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder.typicode.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder.typicode.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder.typicode.com'
    CHECK_STATUS=`curl -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder.typicode.com' --write-out "%{http_code}\n" --silent --output /dev/null http://$KONG_PROXY_HOST:8000/posts/1`

    if [ "$CHECK_STATUS" != "200" ]; then
        echo "OAuth PEP security fail"
        exit 1
    fi
}

function test_uma_auth_and_pep() {
    # =========================================================================
    # UMA Auth and PEP
    echo "========================================================================="
    echo "UMA Auth and PEP"

    SERVICE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/services/  -H 'Content-Type: application/json'  -d '{"name":"jsonplaceholder2","url":"https://jsonplaceholder.typicode.com"}'`

    SERVICE_ID=`echo $SERVICE_RESPONSE | jq -r ".id"`
    echo "SERVICE_ID " .. $SERVICE_ID

    ROUTE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/routes/ -H 'Content-Type: application/json' -d '{"hosts": ["jsonplaceholder2.typicode.com"],"service": {"id": "'$SERVICE_ID'"}}'`

    ROUTE_ID=`echo $ROUTE_RESPONSE | jq -r ".id"`
    echo "ROUTE_ID " .. $ROUTE_ID

    # Create OP Client for UMA_PEP

    OP_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/register-site  -H "Content-Type: application/json" -d  '{"client_name":"test_uma_pep", "op_host":"https://'$OP_HOST'", "redirect_uris": ["https://client.example.com/cb"], "scope": ["openid", "oxd", "uma_protection"], "grant_types":["client_credentials"]}'`

    OXD_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".oxd_id"`
    CLIENT_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".client_id"`
    CLIENT_SECRET=`echo $OP_CLIENT_RESPONSE | jq -r ".client_secret"`
    echo "OXD_ID " .. $OXD_ID
    echo "CLIENT_ID " .. $CLIENT_ID
    echo "CLIENT_SECRET " .. $CLIENT_SECRET

    # Register resources using OXD
    # GET PROTECTION TOKEN
    RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/get-client-token -H "Content-Type: application/json" -d '{"client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","op_host":"'$OP_HOST'", "scope":["openid", "oxd", "uma_protection"]}'`

    TOKEN=`echo $RESPONSE | jq -r ".access_token"`
    echo "PROTECTION TOKEN " .. $TOKEN

    RS_PROTECT_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/uma-rs-protect -H "Authorization: Bearer $TOKEN"  -H "Content-Type: application/json" -d  '{"oxd_id":"'$OXD_ID'","resources":[{"path":"/posts/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["admin","employee"]}}]},{"path":"/comments/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0}]},"data":["admin"]}}]}]}'`

    echo "RS_PROTECT_CLIENT_RESPONSE " .. $RS_PROTECT_CLIENT_RESPONSE

    # Create anonymous kong consumer
    anonymous_CONSUMER_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/consumers/  -H 'Content-Type: application/json'  -d '{"username":"anonymous","custom_id":"anonymous"}'`

    anonymous_CONSUMER_ID=`echo $anonymous_CONSUMER_RESPONSE | jq -r ".id"`
    echo "anonymous CONSUMER_ID " .. $anonymous_CONSUMER_ID

    # Config plugin
    ## UMA-AUTH
    UMA_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins/  -H 'Content-Type: application/json'  -d '{"name":"gluu-uma-auth","config":{"anonymous": "'$anonymous_CONSUMER_ID'", "oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","op_url":"https://'$OP_HOST'","oxd_id":"'$OXD_ID'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","pass_credentials":"pass"},"service_id":"'$SERVICE_ID'"}'`

    UMA_PLUGIN_ID=`echo $UMA_PLUGIN_RESPONSE | jq -r ".id"`
    echo "UMA_AUTH_PLUGIN_ID " .. $UMA_PLUGIN_ID

    ## UMA-PEP
    UMA_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins/  -H 'Content-Type: application/json'  -d '{"name":"gluu-uma-pep","config":{"oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","op_url":"https://'$OP_HOST'","oxd_id":"'$OXD_ID'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","uma_scope_expression":[{"path":"/posts/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0},{"var":1}]},"data":["admin","employee"]}}]},{"path":"/comments/??","conditions":[{"httpMethods":["GET","DELETE","POST","PUT"],"scope_expression":{"rule":{"and":[{"var":0}]},"data":["admin"]}}]}],"deny_by_default":true},"service_id":"'$SERVICE_ID'"}'`

    UMA_PLUGIN_ID=`echo $UMA_PLUGIN_RESPONSE | jq -r ".id"`
    echo "UMA_PEP_PLUGIN_ID " .. $UMA_PLUGIN_ID

    # UMA Auth
    TICKET=`curl -i -sS -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H 'Host: jsonplaceholder2.typicode.com' | sed -n 's/.*ticket="//p'`
    TICKET="${TICKET%??}"
    echo "TICKET " .. $TICKET

    RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/get-client-token -H "Content-Type: application/json" -d '{"client_id":"'$CONSUMER_CLIENT_ID'","client_secret":"'$CONSUMER_CLIENT_SECRET'","op_host":"'$OP_HOST'", "scope":["openid", "oxd", "uma_protection"]}'`

    TOKEN=`echo $RESPONSE | jq -r ".access_token"`
    echo "PROTECTION Token " .. $TOKEN

    RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/uma-rp-get-rpt -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"oxd_id":"'$CONSUMER_OXD_ID'","ticket":"'$TICKET'"}'`

    echo $RESPONSE
    TOKEN=`echo $RESPONSE | jq -r ".access_token"`
    echo "RPT Token " .. $TOKEN

    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder2.typicode.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder2.typicode.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder2.typicode.com'

    CHECK_STATUS=`curl -H "Authorization: Bearer $TOKEN"  -H 'Host: jsonplaceholder2.typicode.com' --write-out "%{http_code}\n" --silent --output /dev/null http://$KONG_PROXY_HOST:8000/posts/1`

    if [ "$CHECK_STATUS" != "200" ]; then
        echo "UMA PEP security fail"
        exit 1
    fi
}

function config_oidc_and_uma_pep() {
    #####################################
    # Configure OIDC Plugin
    #####################################
    if [ "$DISTRIBUTION" == "centos7" ]; then
        yum install git -y
    fi

    git clone https://github.com/ldeveloperl1985/node-ejs.git
    cd node-ejs
    npm i
    npm i -g pm2
    pm2 start app.js

    SERVICE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/services/  -H 'Content-Type: application/json'  -d '{"name":"oidc-plugin-test","url":"http://localhost:4400"}'`

    SERVICE_ID=`echo $SERVICE_RESPONSE | jq -r ".id"`
    echo "SERVICE_ID " .. $SERVICE_ID

    ROUTE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/routes/ -H 'Content-Type: application/json' -d '{"hosts": ["'$HOST'"],"service": {"id": "'$SERVICE_ID'"}}'`

    ROUTE_ID=`echo $ROUTE_RESPONSE | jq -r ".id"`
    echo "ROUTE_ID " .. $ROUTE_ID

    OP_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/register-site -H "Content-Type: application/json" -d '{"op_host":"https://'$OP_HOST'","oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","redirect_uris":["https://'$KONG_PROXY_HOST'/callback"],"client_name":"gg-openid-connect-client","post_logout_redirect_uris":["https://'$KONG_PROXY_HOST'/logout_redirect_uri"],"scope":["openid","oxd","email","profile", "uma_protection"],"acr_values":["auth_ldap_server"],"grant_types":["client_credentials","authorization_code","refresh_token"],"claims_redirect_uri":["https://'$KONG_PROXY_HOST'/claims_callback"]}'`

    echo "OP_CLIENT_RESPONSE: " .. $OP_CLIENT_RESPONSE
    OXD_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".oxd_id"`
    CLIENT_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".client_id"`
    CLIENT_SECRET=`echo $OP_CLIENT_RESPONSE | jq -r ".client_secret"`
    echo "OXD_ID " .. $OXD_ID
    echo "CLIENT_ID " .. $CLIENT_ID
    echo "CLIENT_SECRET " .. $CLIENT_SECRET

    PAT_TOKEN_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/get-client-token -H "Content-Type: application/json" -d '{"op_host":"https://'$OP_HOST'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","scope":["openid","oxd"]}'`
    echo "PAT_TOKEN_RESPONSE:" .. $PAT_TOKEN_RESPONSE
    TOKEN=`echo $PAT_TOKEN_RESPONSE | jq -r ".access_token"`
    echo "PROTECTION Token " .. $TOKEN

    UMA_RS_PROTECT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/uma-rs-protect -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"oxd_id":"'$OXD_ID'","resources":[{"path":"/settings/??","conditions":[{"httpMethods":["GET"],"scope_expression":{"rule":{"and":[{"var":0}]},"data":["with-claims"]}}]}]}'`
    echo "UMA_RS_PROTECT_RESPONSE: " .. $UMA_RS_PROTECT_RESPONSE

    OIDC_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins -H "Content-Type: application/json" -d '{"name":"gluu-openid-connect","route_id":"'$ROUTE_ID'","config":{"oxd_id":"'$OXD_ID'","oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","op_url":"https://'$OP_HOST'","authorization_redirect_path":"/callback","logout_path":"/logout","post_logout_redirect_path_or_url":"/logout_redirect_uri","requested_scopes":["openid","oxd","email","profile", "uma_protection"],"required_acrs_expression":[{"path":"/??","conditions":[{"httpMethods":["?"],"required_acrs":["auth_ldap_server"],"no_auth":false}]},{"path":"/payments/??","conditions":[{"httpMethods":["?"],"required_acrs":["otp"],"no_auth":false}]}],"max_id_token_age":3600,"max_id_token_auth_age":3600}}'`
    echo "OIDC_PLUGIN_RESPONSE: " .. $OIDC_PLUGIN_RESPONSE

    UMA_PEP_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins -H "Content-Type: application/json" -d '{"name":"gluu-uma-pep","route_id":"'$ROUTE_ID'","config":{"oxd_id":"'$OXD_ID'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","op_url":"https://'$OP_HOST'","oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","uma_scope_expression":[{"path":"/settings/??","conditions":[{"httpMethods":["GET"],"scope_expression":{"rule":{"and":[{"var":0}]},"data":["with-claims"]}}]}],"deny_by_default":false,"require_id_token":true,"obtain_rpt":true,"redirect_claim_gathering_url":true,"claims_redirect_path":"/claims_callback"}}'`
    echo "UMA_PEP_PLUGIN_RESPONSE: " .. $UMA_PEP_PLUGIN_RESPONSE
}

function test_gluu_metrics() {
    GLUU_METRICS_RESPONSE=`curl -k -X GET http://localhost:8001/gluu-metrics`
    echo "GLUU_METRICS_RESPONSE: " .. $GLUU_METRICS_RESPONSE
    search_string="gluu_total_client_authenticated 8"
    if [[ $GLUU_METRICS_RESPONSE =~ $search_string ]];
    then
        echo "Metrics Found Successfully"
    else
        echo "Failed to match metrics data gluu_total_client_authenticated 8"
        exit 1
    fi
}

function test_oauth_auth_and_opa_pep() {
    ###################################
    #### Configure OPA PEP
    ###################################
    function docker_xenial {
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get -qqy update
        apt-get -qqy install docker-ce
    }

    function docker_centos7 {
        yum install -y yum-utils device-mapper-persistent-data lvm2
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
    }

    case $DISTRIBUTION in
         "xenial") docker_xenial ;;
         "centos7") docker_centos7 ;;
    esac

    OPA_ID=`docker run -p 8181 -d --name opa openpolicyagent/opa:0.10.5 run --server`
    sleep 5

    OPA_PORT=`docker inspect --format='{{(index (index .NetworkSettings.Ports "8181/tcp") 0).HostPort}}' $OPA_ID`

    SERVICE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/services/  -H 'Content-Type: application/json'  -d '{"name":"OAUTH-AUTH-OPA-Test","url":"https://jsonplaceholder.typicode.com"}'`
    SERVICE_ID=`echo $SERVICE_RESPONSE | jq -r ".id"`
    echo "SERVICE_ID " .. $SERVICE_ID

    ROUTE_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/routes/ -H 'Content-Type: application/json' -d '{"hosts": ["opa-test.com"],"service": {"id": "'$SERVICE_ID'"}}'`
    ROUTE_ID=`echo $ROUTE_RESPONSE | jq -r ".id"`
    echo "ROUTE_ID " .. $ROUTE_ID

    OP_CLIENT_RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/register-site  -H "Content-Type: application/json" -d  '{"client_name":"test_oauth_pep","access_token_as_jwt":true,"rpt_as_jwt":true,"access_token_signing_alg":"RS256", "op_host":"https://'$OP_HOST'", "redirect_uris": ["https://client.example.com/cb"], "grant_types":["client_credentials"]}'`
    OXD_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".oxd_id"`
    CLIENT_ID=`echo $OP_CLIENT_RESPONSE | jq -r ".client_id"`
    CLIENT_SECRET=`echo $OP_CLIENT_RESPONSE | jq -r ".client_secret"`
    echo "OXD_ID " .. $OXD_ID
    echo "CLIENT_ID " .. $CLIENT_ID
    echo "CLIENT_SECRET " .. $CLIENT_SECRET

    cd /root
    wget https://raw.githubusercontent.com/GluuFederation/gluu-gateway/version_4.0/t/scripts/policy.rego
    sed -i '12iinput.request_token_data.client_id = "'$CONSUMER_CLIENT_ID'"' policy.rego
    OPA_POLICY_ADD=`curl -X PUT --data-binary @policy.rego localhost:$OPA_PORT/v1/policies/example`

    OAUTH_PLUGIN_RESPONSE=`curl -k -X POST http://$KONG_ADMIN_HOST:8001/plugins/  -H 'Content-Type: application/json'  -d '{"name":"gluu-oauth-auth","config":{"oxd_url":"https://'$OXD_HOST':'$OXD_PORT'","op_url":"https://'$OP_HOST'","oxd_id":"'$OXD_ID'","client_id":"'$CLIENT_ID'","client_secret":"'$CLIENT_SECRET'","pass_credentials":"pass"},"service_id":"'$SERVICE_ID'"}'`
    echo $OAUTH_PLUGIN_RESPONSE

    OAUTH_PLUGIN_ID=`echo $OAUTH_PLUGIN_RESPONSE | jq -r ".id"`
    echo "OAUTH_AUTH_PLUGIN_ID " .. $OAUTH_PLUGIN_ID

    OPA_PLUGIN_RESPONSE=`curl -v -i -sS -X POST  --url http://$KONG_ADMIN_HOST:8001/plugins/ --header 'content-type: application/json;charset=UTF-8' --data '{"name":"gluu-opa-pep","config":{"opa_url":"http://localhost:'$OPA_PORT'/v1/data/httpapi/authz?pretty=true&explain=full"},"service_id":"'$SERVICE_ID'"}'`
    echo "OPA_PLUGIN_RESPONSE: " .. $OPA_PLUGIN_RESPONSE

    # OAUTH
    RESPONSE=`curl -k -X POST https://$OXD_HOST:$OXD_PORT/get-client-token -H "Content-Type: application/json" -d '{"client_id":"'$CONSUMER_CLIENT_ID'","client_secret":"'$CONSUMER_CLIENT_SECRET'","op_host":"'$OP_HOST'", "scope":["openid", "oxd", "uma_protection"]}'`
    TOKEN=`echo $RESPONSE | jq -r ".access_token"`
    echo "Access Token " .. $TOKEN

    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: opa-test.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: opa-test.com'
    curl -X GET http://$KONG_PROXY_HOST:8000/posts/1 -H "Authorization: Bearer $TOKEN"  -H 'Host: opa-test.com'

    CHECK_STATUS=`curl -H "Authorization: Bearer $TOKEN"  -H 'Host: opa-test.com' --write-out "%{http_code}\n" --silent --output /dev/null http://$KONG_PROXY_HOST:8000/posts/1`

    if [ "$CHECK_STATUS" != "200" ]; then
        echo "OAuth PEP security fail"
        exit 1
    fi

    ss -ntlp
}

test_oauth_auth_and_pep
test_uma_auth_and_pep
config_oidc_and_uma_pep
test_gluu_metrics
test_oauth_auth_and_opa_pep

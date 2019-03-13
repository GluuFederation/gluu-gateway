#!/bin/bash

#--- SETTING DEFAULT VALUES ---
export IP_ADDRESS=${IP_ADDRESS:=""}
export HOSTNAME=${HOSTNAME:=""}
export TWO_LETTER_COUNTRY_CODE=${TWO_LETTER_COUNTRY_CODE:=""}
export TWO_LETTER_STATE_CODE=${TWO_LETTER_STATE_CODE:=""}
export CITY_OR_LOCATION=${CITY_OR_LOCATION:=""}
export ORGANIZATION_NAME=${ORGANIZATION_NAME:=""}
export EMAIL_ADDRESS=${EMAIL_ADDRESS:=""}
export PGSQL_PASSWORD=${PGSQL_PASSWORD:=""}
export OP_HOST=${OP_HOST:=""}
export OXD_SERVER_URL=${OXD_SERVER_URL:=""}
export GENERATE_CLIENT_CREDS_FOR_OXD=${GENERATE_CLIENT_CREDS_FOR_OXD:=""}
export OXD_ID=${OXD_ID:=""}
export CLIENT_ID=${CLIENT_ID:=""}
export CLIENT_SECRET=${CLIENT_SECRET:=""}
export LICENSE=${LICENSE:=""}

sed -i "s/\$IP_ADDRESS/$IP_ADDRESS/g" setup-gluu-gateway_template.py
sed -i "s/\$HOSTNAME/$HOSTNAME/g" setup-gluu-gateway_template.py
sed -i "s/\$TWO_LETTER_COUNTRY_CODE/$TWO_LETTER_COUNTRY_CODE/g" setup-gluu-gateway_template.py
sed -i "s/\$TWO_LETTER_STATE_CODE/$TWO_LETTER_STATE_CODE/g" setup-gluu-gateway_template.py
sed -i "s/\$CITY_OR_LOCATION/$CITY_OR_LOCATION/g" setup-gluu-gateway_template.py
sed -i "s/\$ORGANIZATION_NAME/$ORGANIZATION_NAME/g" setup-gluu-gateway_template.py
sed -i "s/\$EMAIL_ADDRESS/$EMAIL_ADDRESS/g" setup-gluu-gateway_template.py
sed -i "s/\$PGSQL_PASSWORD/$PGSQL_PASSWORD/g" setup-gluu-gateway_template.py
sed -i "s/\$OP_HOST/$OP_HOST/g" setup-gluu-gateway_template.py
sed -i "s/\$OXD_SERVER_URL/$OXD_SERVER_URL/g" setup-gluu-gateway_template.py
sed -i "s/\$GENERATE_CLIENT_CREDS_FOR_OXD/$GENERATE_CLIENT_CREDS_FOR_OXD/g" setup-gluu-gateway_template.py
sed -i "s/\$OXD_ID/$OXD_ID/g" setup-gluu-gateway_template.py
sed -i "s/\$CLIENT_ID/$CLIENT_ID/g" setup-gluu-gateway_template.py
sed -i "s/\$CLIENT_SECRET/$CLIENT_SECRET/g" setup-gluu-gateway_template.py
sed -i "s/\$LICENSE/$LICENSE/g" setup-gluu-gateway_template.py

#!/bin/bash

# Command line argument for qcow2 file
QCOW2_FILE=$1

# Run the hpe-vm command in the background
sudo /usr/bin/hpe-vm --install \
    -a 192.168.128.243 \
    -g 192.168.128.1 \
    -D 4.2.2.2 \
    -n 255.255.255.0 \
    -H vmemanager \
    -U rmadmin \
    -P "Password123#" \
    -u https://192.168.128.243 \
    -i ens1 \
    -q /mnt/demo/$QCOW2_FILE \
    -d &

HPE_VM_PID=$!

# Poll for the HTTPS address to respond
URL="https://192.168.128.243"
MAX_ATTEMPTS=60
SLEEP_SECONDS=30
ATTEMPT=1

echo "Waiting for $URL to respond..."

while (( ATTEMPT <= MAX_ATTEMPTS )); do
    if curl -k --silent --head --fail "$URL" > /dev/null; then
        echo "$URL is responding."
        curl -k --request POST \
            --url https://192.168.128.243/api/setup \
            --header 'accept: application/json' \
            --header 'content-type: application/json' \
            --data '
        {
        "applianceName": "RMVME",
        "applianceUrl": "https://192.168.128.243",
        "accountName": "RMLAB",
        "firstName": "RiverMeadow",
        "lastName": "Admin",
        "username": "rmadmin",
        "email": "rmadmin@test.local",
        "password": "Password123#"
        }
        '


        # Wait for auth service to initialize before validating credentials
        sleep 30

        # Poll OAuth endpoint until credentials are accepted
        AUTH_URL="https://192.168.128.243/oauth/token"
        AUTH_MAX_ATTEMPTS=20
        AUTH_SLEEP_SECONDS=15
        AUTH_ATTEMPT=1

        echo "Validating credentials against $AUTH_URL..."

        while (( AUTH_ATTEMPT <= AUTH_MAX_ATTEMPTS )); do
            HTTP_STATUS=$(curl -k -s -o /dev/null -w "%%{http_code}" -X POST "$AUTH_URL" \
                -d "grant_type=password" \
                -d "client_id=morph-api" \
                -d "username=rmadmin" \
                -d "password=Password123#" \
                -d "scope=write")

            if [[ "$HTTP_STATUS" == "200" ]]; then
                echo "Authentication successful (HTTP $HTTP_STATUS). Credentials are valid."
                exit 0
            else
                echo "Auth attempt $AUTH_ATTEMPT/$AUTH_MAX_ATTEMPTS: received HTTP $HTTP_STATUS. Retrying in $AUTH_SLEEP_SECONDS seconds..."
                sleep $AUTH_SLEEP_SECONDS
                ((AUTH_ATTEMPT++))
            fi
        done

        echo "ERROR: Authentication failed after $((AUTH_MAX_ATTEMPTS * AUTH_SLEEP_SECONDS)) seconds."
        exit 1
    else
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: $URL not responding yet. Retrying in $SLEEP_SECONDS seconds..."
        sleep $SLEEP_SECONDS
        ((ATTEMPT++))
    fi
done

echo "ERROR: $URL did not respond after $((MAX_ATTEMPTS * SLEEP_SECONDS)) seconds."
exit 1
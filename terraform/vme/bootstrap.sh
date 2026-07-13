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
    -i enp1s0 \
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
        exit 0
    else
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: $URL not responding yet. Retrying in $SLEEP_SECONDS seconds..."
        sleep $SLEEP_SECONDS
        ((ATTEMPT++))
    fi
done

echo "ERROR: $URL did not respond after $((MAX_ATTEMPTS * SLEEP_SECONDS)) seconds."
exit 1
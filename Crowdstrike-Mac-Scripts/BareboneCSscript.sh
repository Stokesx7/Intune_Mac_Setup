#!/bin/bash

# Configuration - ensure that these variables are securely stored and loaded, avoid hardcoding in practice
CLIENT_ID="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
BASE_URL="what.ever.your.https for API key"
FILE_NAME="GovLaggar_Release_standard-p_18701.pkg" 
CS_CCID="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xx"
CS_INSTALL_TOKEN="xxxxxxxx"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to obtain access token
get_access_token() {
    json=$(curl -s -X POST -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}" "${BASE_URL}/oauth2/token")
    echo "function run() { let result = JSON.parse(\`$json\`); return result.access_token; }" | osascript -l JavaScript
}

# Function to get SHA256 hash of the installer
get_sha256() {
    json=$(curl -s -H "Authorization: Bearer ${1}" "${BASE_URL}/sensors/combined/installers/v1?filter=platform%3A%22mac%22")
    echo "function run() { let result = JSON.parse(\`$json\`); return result.resources[0].sha256; }" | osascript -l JavaScript
}

# Check if Falcon is installed and operational
if [ ! -x "/Applications/Falcon.app/Contents/Resources/falconctl" ] || [ -z "$(/Applications/Falcon.app/Contents/Resources/falconctl stats | grep 'Sensor operational: true')" ]; then
    APITOKEN=$(get_access_token)
    FALCON_LATEST_SHA256=$(get_sha256 "${APITOKEN}")
    
    # Download and install the latest Falcon sensor
    curl -o "/private/tmp/${FILE_NAME}" -s -H "Authorization: Bearer ${APITOKEN}" "${BASE_URL}/sensors/entities/download-installer/v1?id=${FALCON_LATEST_SHA256}"
    installer -verboseR -pkg "/private/tmp/${FILE_NAME}" -target /
    rm "/private/tmp/${FILE_NAME}"

    # Run falconctl license with the given CCID and token
    sudo /Applications/Falcon.app/Contents/Resources/falconctl license "${CS_CCID}" "${CS_INSTALL_TOKEN}" --load || true
else
    echo "Crowdstrike Falcon is installed and operational"
fi
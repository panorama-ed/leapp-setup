#!/bin/bash

kernel_name=$(uname -s)

# If the utils.sh file is not present, download & run it
if [[ ! -e "utils.sh" ]]; then
    eval "$(curl -Ls 'https://raw.githubusercontent.com/panorama-ed/leapp-setup/main/utils.sh')"
else
    . ./utils.sh
fi

if [[ -z "${INTEGRATION_PORTAL_URL}" ]]; then
    red_echo "INTEGRATION_PORTAL_URL must be provided"
    exit
fi

if [[ -z "${LEAPP_ROLES}" ]]; then
    red_echo "LEAPP_ROLES must be provided"
    exit
fi

if [[ "$kernel_name" == "Darwin" ]]; then
    # Leapp integration setup
    LEAPP=/Applications/Leapp.app
    leapp_proc_name=Leapp
elif [[ "$kernel_name" == "Linux" ]]; then
    LEAPP=/opt/Leapp/leapp
    leapp_proc_name=leapp
fi

# Check if Leapp is installed
if [ -e "$LEAPP" ]; then
    # If Leapp is not running, open it and wait for it to start up
    if ! pgrep -x $leapp_proc_name &>/dev/null; then
        if [[ $kernel_name == "Darwin" ]]; then
            open $LEAPP
        elif [[ $kernel_name == "Linux" ]]; then
            $LEAPP &
        fi
        sleep 5
    fi

    # If there's no Panorama integration, set it up
    if ! leapp integration list --no-header | grep -i Panorama; then
        leapp integration create \
            --integrationType AWS-SSO \
            --integrationAlias Panorama \
            --integrationPortalUrl $INTEGRATION_PORTAL_URL \
            --integrationRegion us-east-1
    fi

    PANORAMA_INTEGRATION=$(
        leapp integration list --csv --columns=ID,"Integration Name","Status" \
        | grep Panorama
    )

    INTEGRATION_ID=$(echo $PANORAMA_INTEGRATION | awk -F$',' '{print $1;}')
    INTEGRATION_STATUS=$(echo $PANORAMA_INTEGRATION | awk -F$',' '{print $3;}')

    if [[ $INTEGRATION_STATUS == "Offline" ]]; then
        leapp integration login --integrationId $INTEGRATION_ID
    fi

    function set_profile_id() {
        PROFILE_ID=$(
            leapp profile list --csv --columns=ID,'Profile Name' \
            | grep $ROLE_NAME \
            | awk  -F$',' '{print $1;}'
        )
    }

    AVAILABLE_LEAPP_SESSIONS=$(
        leapp session list --csv --columns=id,role |
        grep -E $LEAPP_ROLES
    )

    while IFS= read -r line; do
        SESSION_ID=$(echo $line | awk  -F$',' '{print $1;}')
        ROLE_NAME=$(echo $line | awk -F$',' '{print $2;}')

        echo "Creating $ROLE_NAME profile"

        set_profile_id

        # If the role's name is not in the list of existing profiles, create it.
        if [ -z "$PROFILE_ID" ]; then
            leapp profile create --profileName $ROLE_NAME

            set_profile_id
        fi

        # Associate the session with the profile matching the role.
        leapp session change-profile --profileId $PROFILE_ID --sessionId $SESSION_ID
    done <<< "$AVAILABLE_LEAPP_SESSIONS"

    # If we found at least one available session, then we can presume
    # this installation was successful.
    if (( $(echo "$AVAILABLE_LEAPP_SESSIONS" | wc -l) > 0 )); then
        echo "+++++ Installation successful. +++++"
    else
        red_echo "----- Error during installation.  Please share the above output to the Infra/Ops Zone. -----"
    fi
else
    red_echo "Leapp has not been installed."
fi

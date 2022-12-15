#!/bin/bash
# xcode command line tools installation will hang on OS versions lower than this
MIN_OS_VERSION="12.4.0"
CURRENT_OS_VERSION=$(sw_vers -productVersion)

red_echo () { echo -ne "\033[1;31m"; echo -n "$@"; echo -e "\033[0m"; }

# use version sorting to check if the current version is less than $MIN_OS_VERSION
if [[ $MIN_OS_VERSION != "$(printf "$MIN_OS_VERSION\n$CURRENT_OS_VERSION" | sort -V | sed -n 1p)" ]]; then
    red_echo "MacOS minimum required version is ${MIN_OS_VERSION}. The installed version is ${CURRENT_OS_VERSION}. Please update your OS before running this script."
    exit
fi

if [[ -z "${INTEGRATION_PORTAL_URL}" ]]; then
    red_echo "INTEGRATION_PORTAL_URL must be provided"
    exit
fi

if [[ -z "${LEAPP_ROLES}" ]]; then
    red_echo "LEAPP_ROLES must be provided"
    exit
fi

# Install Homebrew if not installed
# This may optionally install the Xcode CLT if it is not already installed.
which -s brew
if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # If using an M1 machine, load shell environment to run brew commands
    if [[ $(uname -m) == 'arm64' ]]; then
        echo ‘# Set PATH, MANPATH, etc., for Homebrew.’ >> ~/.zprofile
        echo ‘eval "$(/opt/homebrew/bin/brew shellenv)"’ >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# The AWS CLI requires python
brew install python
# The AWS credential files require the AWS CLI to be installed
brew install awscli

# If using an M1 machine, add a symlink for the AWS credential files to where Leapp expects them
if [[ $(uname -m) == 'arm64' ]]; then
    sudo ln -s /opt/homebrew/bin/aws /usr/local/bin/aws
fi

# If the app store version of filezilla is installed, it expects the .aws credentials
# to be in the filezilla installation directory.  Add a symlink there.
if [ -d ~/Library/Containers/org.filezilla-project.filezilla.sandbox ]; then
    ln -s ~/.aws ~/Library/Containers/org.filezilla-project.filezilla.sandbox/Data/.aws
fi

# Install session manager plugin
brew install --cask session-manager-plugin

# Install Leapp CLI
brew install Noovolari/brew/leapp-cli

# Leapp integration setup
LEAPP=/Applications/Leapp.app

# Check if Leapp is installed
if [ -d "$LEAPP" ]; then
    # If Leapp is not running, open it and wait for it to start up
    if ! pgrep -x Leapp &>/dev/null; then
        open $LEAPP
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

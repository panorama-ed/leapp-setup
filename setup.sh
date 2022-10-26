if [[ -z "${INTEGRATION_PORTAL_URL}" ]]; then
    echo "INTEGRATION_PORTAL_URL must be provided"
    exit
fi

if [[ -z "${LEAPP_ROLES}" ]]; then
    echo "LEAPP_ROLES must be provided"
    exit
fi

# Install the xcode Command Line Tools, if they are not installed
xcode-select --install

# Install Homebrew if not installed
which -s brew
if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
fi

# The AWS CLI requires python
brew install python
# The AWS credential files require the AWS CLI to be installed
brew install awscli

# If using an M1 machine, add a symlink for the AWS credential files to where Leapp expects them
if [[ ! -f /usr/local/bin/aws ]]; then
    ln -s /opt/homebrew/bin/aws /usr/local/bin/aws
fi

# For the app store version of filezilla, it expects the .aws credentials
# to be in the filezilla installation directory.  Add a symlink there.
ln -s ~/.aws ~/Library/Containers/org.filezilla-project.filezilla.sandbox/Data/.aws

# Install session manager plugin
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip -o sessionmanager-bundle.zip
python3 sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
rm -rf sessionmanager-bundle

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

    ARE_ROLES_AVAILABLE=0

    # Update the Development & S3-only sessions so the profile names match
    #   their roles.  This allows simpler setup instructions.
    #
    # *Development profiles are expected by Docker during local dev for AWS
    #   credentials.
    #
    # SFTP & ClientSourced sessions provide S3-only access and used for SFTP
    #   clients (e.g. Filezilla & Cyberduck).
    leapp session list --csv --columns=id,role |
    grep -E $LEAPP_ROLES |
    while read -r line ; do
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

        ARE_ROLES_AVAILABLE=1
    done

    echo "\nInstallation successful."
else
    echo "Leapp has not been installed."
fi
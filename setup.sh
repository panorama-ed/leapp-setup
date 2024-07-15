#!/bin/bash
# Arguments as environment variables:
# CONFIGURE_LEAPP: 0 to skip configuration, unset or other value will ask for input
# INTEGRATION_PORTAL_URL: See https://panoramaed.atlassian.net/wiki/spaces/ENG/pages/2847113303/Leapp
# LEAPP_ROLES: See https://panoramaed.atlassian.net/wiki/spaces/ENG/pages/2847113303/Leapp

# xcode command line tools installation will hang on OS versions lower than this
MIN_OS_VERSION="12.4.0"
kernel_name=$(uname -s)

# If the utils.sh file is not present, download & run it
if [[ ! -e "utils.sh" ]]; then
    eval "$(curl -Ls 'https://raw.githubusercontent.com/panorama-ed/leapp-setup/main/utils.sh')"
else
    . ./utils.sh
fi

if [[ "$kernel_name" != 'Darwin' ]] && [[ "$kernel_name" != 'Linux' ]]; then
    red_echo "This script is only supported on MacOS and Linux."
    exit
fi

if [[ "$kernel_name" == 'Darwin' ]]; then
  CURRENT_OS_VERSION=$(sw_vers -productVersion)
  # use version sorting to check if the current version is less than $MIN_OS_VERSION
  if [[ $MIN_OS_VERSION != "$(printf "$MIN_OS_VERSION\n$CURRENT_OS_VERSION" | sort -V | sed -n 1p)" ]]; then
      red_echo "MacOS minimum required version is ${MIN_OS_VERSION}. The installed version is ${CURRENT_OS_VERSION}. Please update your OS before running this script."
      exit
  fi
fi

if [[ "${CONFIGURE_LEAPP}" != "0" ]] && [[ -z "${INTEGRATION_PORTAL_URL}" ]]; then
    red_echo "INTEGRATION_PORTAL_URL must be provided"
    exit
fi

if [[ "${CONFIGURE_LEAPP}" != "0" ]] && [[ -z "${LEAPP_ROLES}" ]]; then
    red_echo "LEAPP_ROLES must be provided"
    exit
fi


# If using Linux, create /home/<user>/ using sudo permission
if [[ "$kernel_name" == "Linux" ]] && [[ ! -e "/home/$(whoami)" ]]; then
    sudo mkdir -p "/home/$(whoami)"
    if id -gn | grep 'users' > /dev/null; then
        group='users'
    else
        group=$(id -gn | cut -d ' ' -f 1)
    fi
    sudo chown -R "$(whoami):$group" "/home/$(whoami)"
fi

# Install Homebrew if not installed
# This may optionally install the Xcode CLT if it is not already installed.
if [[ "$kernel_name" == 'Darwin' ]] && ! which brew > /dev/null ; then

    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # If using an M1 machine, load shell environment to run brew commands
    if [[ $(uname -m) == 'arm64' ]]; then
        echo '# Set PATH, MANPATH, etc., for Homebrew.' >> ~/.zprofile
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

if [[ "$kernel_name" == "Darwin" ]]; then
  # The AWS CLI requires python
  brew install python
  # The AWS credential files require the AWS CLI to be installed
  brew install awscli
elif [[ "$kernel_name" == "Linux" ]]; then
  # The AWS CLI requires python
  sudo apt install -y python3
  # The AWS credential files require the AWS CLI to be installed
  sudo apt install -y awscli
fi

# If using an M1 machine, add a symlink for the AWS credential files to where Leapp expects them
if [[ "$kernel_name" == "Darwin" ]] && [[ $(uname -m) == 'arm64' ]]; then
    sudo ln -s /opt/homebrew/bin/aws /usr/local/bin/aws
fi

# If the app store version of filezilla is installed, it expects the .aws credentials
# to be in the filezilla installation directory.  Add a symlink there.
if [[ "$kernel_name" == "Darwin" ]] && [ -d ~/Library/Containers/org.filezilla-project.filezilla.sandbox ]; then
    ln -s ~/.aws ~/Library/Containers/org.filezilla-project.filezilla.sandbox/Data/.aws
fi

# Install session manager plugin
if [[ "$kernel_name" == "Darwin" ]]; then
    brew install --cask session-manager-plugin
elif [[ "$kernel_name" == "Linux" ]] && ! dpkg -l session-manager-plugin; then
    mkdir ~/Downloads/
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o ~/Downloads/session-manager-plugin.deb
    sudo dpkg -i ~/Downloads/session-manager-plugin.deb
    rm session-manager-plugin.deb
fi

# Install Leapp CLI
if [[ "$kernel_name" == "Darwin" ]]; then
    brew install Noovolari/brew/leapp-cli
else [[ "$kernel_name" == "Linux" ]]
    mkdir ~/Downloads/
    if ! dpkg -l leapp; then
        sudo apt install -y libfuse2
        # Whenever a new Leapp version is updated, this link will break
        curl https://asset.noovolari.com/latest/Leapp_0.26.1_amd64.deb -o ~/Downloads/leapp.deb
        sudo dpkg -i ~/Downloads/leapp.deb
        sudo mv /usr/bin/leapp /usr/bin/leapp-desktop
    fi
    curl -fsSL https://deb.nodesource.com/setup_22.x -o ~/Downloads/nodesource_setup.sh
    sudo bash ~/Downloads/nodesource_setup.sh
    sudo apt install -y nodejs
    sudo apt install -y npm
    sudo npm install -g @noovolari/leapp-cli
fi

if [[ "${CONFIGURE_LEAPP}" == "0" ]]; then
    exit
fi

# If the config.sh file is not present, download & run it
if [[ ! -e "config.sh" ]]; then
    eval "$(curl -Ls 'https://raw.githubusercontent.com/panorama-ed/leapp-setup/main/config.sh')"
else
    . ./config.sh
fi

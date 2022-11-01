while true; do
    read -p "Running this script will uninstall the Leapp CLI, Homebrew, and xcode Command Line Tools. It is meant to revert the setup.sh for testing it.  Do you wish to continue? [Yes / No] " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Uninstall Leapp CLI
brew uninstall Noovolari/brew/leapp-cli
# Uninstall Session Manager Plugin
sudo rm -rf /usr/local/sessionmanagerplugin
sudo rm /usr/local/bin/session-manager-plugin
# Uninstall AWS CLI
brew uninstall awscli
# Uninstall python
brew uninstall python --ignore-dependencies python
# Uninstall homebrew
sudo /bin/bash -cf "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
# Uninstall xcode
sudo rm -rf /Library/Developer/CommandLineTools

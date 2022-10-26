# Uninstall Leapp CLI
brew uninstall Noovolari/brew/leapp-cli
# Uninstall Session Manager
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
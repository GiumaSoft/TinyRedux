#!/bin/zsh

set -e  # Exit immediately on error
set -u  # Error on unset variables

if ! command -v tuist &> /dev/null; then
  echo "Tuist is not installed."
  if ! command -v mise &> /dev/null; then
    echo "Mise is not installed. Installing Mise..."
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "Mise installed successfully."
    mise --version
  else
    echo "Mise is already installed."
  fi

  echo "Installing Tuist..."
  mise install tuist@latest
  mise use -g tuist@latest
  export PATH="$HOME/.local/share/mise/installs/tuist/latest/bin:$PATH"
  echo "Tuist installed successfully."
  tuist version

else  
  echo "Tuist is already installed. Skipping installation."
fi

echo "Clearing existings project and workspace files..."
find . -name "Example/*.xcodeproj" -delete
find . -name "Example/*.xcworkspace" -delete

tuist install
tuist generate --path Example/

echo "Setup completed successfully."

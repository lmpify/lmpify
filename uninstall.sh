#!/usr/bin/env bash
# Copyright 2024 lmpify
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ANSI escape codes for colored bold text.
BLUE_BOLD='\033[1;34m'
RED_BOLD='\033[1;31m'
GREEN_BOLD='\033[1;32m'
RESET='\033[0m'

function remove_lmpify() {
  # Remove the `${HOME}/.lmpify/` directory.
  echo -e "${BLUE_BOLD}Removing the ${HOME}/.lmpify/ directory${RESET}"
  rm -rf "${HOME}/.lmpify"
}

# Function to remove the alias from the user's shell configuration file.
function remove_alias() {
  # Detect the shell type and modify the appropriate configuration file.
  if [[ "$SHELL" =~ "bash" ]]; then
    SHELL_RC="$HOME/.bashrc"
  elif [[ "$SHELL" =~ "zsh" ]]; then
    SHELL_RC="$HOME/.zshrc"
  elif [[ "$SHELL" =~ "fish" ]]; then
    SHELL_RC="$HOME/.config/fish/config.fish"
  else
    echo -e "${RED_BOLD} Unsupported shell: $SHELL${RESET}"
    exit 1
  fi

  # Remove the alias from the shell configuration file.
  echo -e "${BLUE_BOLD}Removing the lmpify alias from ${SHELL_RC}${RESET}"
  OS_TYPE=$(uname -s)

  # Handle the differences in the `sed` command for macOS and Linux.
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    sed -i '' '/^alias lmpify/d' "$SHELL_RC"
  else
    sed -i '/^alias lmpify/d' "$SHELL_RC"
  fi
}

# The entry point of the script.
remove_lmpify
remove_alias
echo -e "${GREEN_BOLD}lmpify has been successfully uninstalled.${RESET}"

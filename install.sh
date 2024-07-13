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

GITHUB_USERNAME=$(gh api /user --jq .login)
DSTINATION_IMAGE_REGISTRY=""
DSTINATION_IMAGE_REGISTRY_NAMESPACE=""
DEFAULT_INSTALL_PATH="$HOME/.lmpify"

# ANSI escape codes for colored bold text.
BLUE_BOLD='\033[1;34m'
GREEN_BOLD='\033[1;32m'
RED_BOLD='\033[1;31m'
WHITE_BOLD='\033[1m'
RESET='\033[0m'

function help() {
  echo -e "${WHITE_BOLD}Usage:${RESET}"
  echo "    ./install.sh [options]"
  echo -e "${WHITE_BOLD}Options:${RESET}"
  echo "    -u | --username <github-username>              The GitHub username that used for running the GitHub Actions workflow."
  echo "    -r | --registry <destination-image-registry>   The destination image registry that used for storing the pulled images. Example: 'registry.cn-hangzhou.aliyuncs.com'"
  echo "    -n | --namespace <destination-image-namespace> The destination image registry namespace that used for storing the pulled images. Example: 'lmpify'"
  echo "    -h | --help                                    Show this help message."
  echo -e "${WHITE_BOLD}Example:${RESET}"
  echo "    ./install.sh --username lmpify --registry registry.cn-hangzhou.aliyuncs.com --namespace lmpify"
}

function parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -u|--username) GITHUB_USERNAME="$2"; shift ;;
      -r|--registry) DSTINATION_IMAGE_REGISTRY="$2"; shift ;;
      -n|--namespace) DSTINATION_IMAGE_REGISTRY_NAMESPACE="$2"; shift ;;
      -h|--help) help; exit 0 ;;
      *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
  done
}

function check_args() {
  if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED_BOLD}GitHub username not provided.${RESET}"
    exit 1
  fi

  if [ -z "$DSTINATION_IMAGE_REGISTRY" ]; then
    echo -e "${RED_BOLD}Destination registry not provided.${RESET}"
    exit 1
  fi

  if [ -z "$DSTINATION_IMAGE_REGISTRY_NAMESPACE" ]; then
    echo -e "${RED_BOLD}Destination registry namespace not provided.${RESET}"
    exit 1
  fi
}

function install_lmpify() {
  if wget -P "$DEFAULT_INSTALL_PATH" https://raw.githubusercontent.com/lmpify/lmpify/main/lmpify.sh && chmod +x "$DEFAULT_INSTALL_PATH/lmpify.sh"; then
    echo -e "${GREEN_BOLD}Install lmpify.sh successfully${RESET}"
  else
    echo -e "${RED_BOLD}Failed to install lmpify${RESET}"
    exit 1
  fi
}

# Function to set alias in the user's shell configuration file.
function set_alias() {
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

  ALIAS_CMD="alias lmpify='$DEFAULT_INSTALL_PATH/lmpify.sh -u ${GITHUB_USERNAME} -r $DSTINATION_IMAGE_REGISTRY -n $DSTINATION_IMAGE_REGISTRY_NAMESPACE -i'"

  # Append alias command to shell config file if it does not already exist.
  if ! grep -q "alias lmpify" "$SHELL_RC"; then
    echo "$ALIAS_CMD" >> "$SHELL_RC"
    printf "${GREEN_BOLD}Adding alias command to %s successfully${RESET}\n" "$SHELL_RC"
  else
    echo -e "${BLUE_BOLD} Alias already exists in $SHELL_RC${RESET}"
  fi

  echo -e "${GREEN_BOLD}Installation completed successfully${RESET}"
  echo -e "${BLUE_BOLD}Please source your shell configuration file to start using the lmpify alias.${RESET}"
  echo -e "${BLUE_BOLD}Example:${RESET}"
  echo -e "${WHITE_BOLD}   source ${SHELL_RC} && lmpify ubuntu:22.04 && docker run -it ubuntu:22.04 bash${RESET}"
}

# The entry point of the script.
parse_args "$@"
check_args
install_lmpify
set_alias

#!/usr/bin/env bash
# A collection of utility functions to be sourced by other scripts

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

red_echo () { echo -e "${RED}$*${NC}"; }
green_echo () { echo -e "${GREEN}$*${NC}"; }
yellow_echo () { echo -e "${YELLOW}$*${NC}"; }

logStdErr() {
    while read -r line; do
        red_echo "$line" >&2
    done
}

#!/usr/bin/env bash

. ../demo-magic.sh

DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

make clean

clear

pe "make build"

pe "make sign"

pe "make push"

pe "make verify"

p ""

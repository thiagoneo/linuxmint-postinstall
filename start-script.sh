#!/usr/bin/env bash

wget https://github.com/thiagoneo/linuxmint-postinstall/archive/refs/tags/21.1.13.tar.gz
tar -xzvf 21.1.13.tar.gz
cd linuxmint-postinstall-21.1.13/
chmod +x *.sh

bash script.sh

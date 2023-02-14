#!/usr/bin/env bash

wget https://github.com/thiagoneo/linuxmint-postinstall/archive/refs/tags/21.1.0.tar.gz
tar -xzvf 21.1.0.tar.gz
cd linuxmint-postinstall-21.1.0/
chmod +x *.sh

bash script.sh

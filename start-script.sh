#!/usr/bin/env bash

wget https://github.com/thiagoneo/linuxmint-postinstall/archive/refs/tags/21.1.3.tar.gz
tar -xzvf 21.1.3.tar.gz
cd linuxmint-postinstall-21.1.3/
chmod +x *.sh

bash script.sh

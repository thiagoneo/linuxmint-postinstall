#!/usr/bin/env bash

wget https://github.com/thiagoneo/linuxmint-postinstall/archive/refs/tags/21.1.10.tar.gz
tar -xzvf 21.1.10.tar.gz
cd linuxmint-postinstall-21.1.10/
chmod +x *.sh

bash script.sh

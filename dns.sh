#!/bin/bash

DNS1=$(\
        dialog --no-cancel --title "DNS primário"\
            --inputbox "Insira o servidor DNS primário:" 8 40\
        3>&1 1>&2 2>&3 3>&- \
    )

DNS2=$(\
        dialog --no-cancel --title "DNS secundário"\
            --inputbox "Insira o servidor DNS secundário (opcional):" 8 40\
        3>&1 1>&2 2>&3 3>&- \
    )

IFS=$'\n'

for CONN_NAME in $(nmcli --fields NAME --terse connection show)
do
    sudo nmcli connection modify  "$CONN_NAME" ipv4.ignore-auto-dns true
    sudo nmcli connection modify  "$CONN_NAME" ipv4.dns "${DNS1} ${DNS2}"
    sudo nmcli connection down "$CONN_NAME"
    sudo nmcli connection up "$CONN_NAME"
done
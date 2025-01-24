#!/bin/bash
PATH=/usr/bin
ALERT="Assinatura detectada pelo ClamAV: $CLAM_VIRUSEVENT_VIRUSNAME em $CLAM_VIRUSEVENT_FILENAME"

# Send an alert to all graphical users.
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
        /usr/bin/notify-send -u normal -i dialog-warning "Virus found!" "$ALERT"
    /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
        /usr/bin/notify-send -u critical -i dialog-warning "Arquivo malicioso encontrado!" "$ALERT"
done

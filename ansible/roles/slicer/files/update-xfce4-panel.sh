#!/usr/bin/env bash

# Adapted from https://forum.xfce.org/viewtopic.php?pid=32033#p32033

# Get the next available plugin ID
NEXT_ID=$(($(xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -a | grep -v "Value is an\|^$" | sort -n | tail -1) + 1))

mkdir -p /home/exouser/.config/xfce4/panel/launcher-$NEXT_ID

cp /usr/share/applications/Slicer.desktop /home/exouser/.config/xfce4/panel/launcher-$NEXT_ID

# Add the new launcher plugin
xfconf-query -c xfce4-panel -p /plugins/plugin-$NEXT_ID -t string -s "launcher" --create
xfconf-query -c xfce4-panel -p /plugins/plugin-$NEXT_ID/items -t string -a -s "Slicer.desktop" --create

# Get the current plugin-ids
PLUGIN_IDS=($(xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -a | grep -v "Value is an\|^$"))

# Insert the new launcher ID in the second place
NEW_PLUGIN_IDS=(${PLUGIN_IDS[0]} $NEXT_ID ${PLUGIN_IDS[@]:1})

# Delete the plugin-ids array
xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -rR

# Create the xfconf-query command with each plugin ID as a separate -t int -s argument
XFCONF_CMD="xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -n -a"
for ID in "${NEW_PLUGIN_IDS[@]}"; do
  XFCONF_CMD+=" -t int -s $ID"
done

# Execute the generated command
eval $XFCONF_CMD

# Trigger panel restart
pkill --signal SIGKILL xfce4-panel

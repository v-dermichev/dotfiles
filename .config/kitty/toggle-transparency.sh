#!/bin/bash

CONF=~/.config/kitty/current-theme.conf

if grep -q 'background_opacity 0.9' "$CONF"; then
	sed -i 's/background_opacity 0.9/background_opacity 1/g' "$CONF"
	echo "Done! Reload kitty config!"
elif grep -q 'background_opacity 1' "$CONF"; then
	sed -i 's/background_opacity 1/background_opacity 0.9/g' "$CONF"
	echo "Done! Reload kitty config!"
else
	echo "There's no background_opacity present in the current kitty theme..."
fi

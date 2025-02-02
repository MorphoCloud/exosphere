OUTPUT="VNC-0"

# List of resolutions to add
RESOLUTIONS=(
  "3200 1800 60.00"
  "2880 1800 60.00"
  "2560 1600 60.00"
  "2560 1440 60.00"
  "2048 1536 60.00"
  "2048 1152 60.00"
)

for RES in "${RESOLUTIONS[@]}"; do
  WIDTH=$(echo $RES | cut -d' ' -f1)
  HEIGHT=$(echo $RES | cut -d' ' -f2)
  RATE=$(echo $RES | cut -d' ' -f3)

  MODELINE=$(cvt $WIDTH $HEIGHT $RATE | grep "Modeline" | sed 's/Modeline //' | tr -d '"')
  MODENAME=$(echo $MODELINE | cut -d' ' -f1 | tr -d '"')

  xrandr --newmode $MODELINE
  xrandr --addmode $OUTPUT $MODENAME
done

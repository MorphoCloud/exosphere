#!/usr/bin/env bash

# This script manages the automatic shelving mechanism for a running instance on a Linux system.
# It can either ask the user if they want to extend the instance runtime by 4 hours, 
# display the time elapsed since the last modification of the shelving tracker file, 
# or update the tracker file's timestamp to the current time if no arguments are provided.
#
# Arguments:
#   -a : Displays a dialog using the "zenity" program, asking the user whether to extend the instance runtime 
#        for an additional 4 hours. This option is only triggered if the elapsed time since the last modification 
#        is between 3.5 and 4.0 hours.
#   -d : Displays the number of hours that have passed since the shelving tracker file was last modified.
#
# Behavior when no arguments are provided:
#   If no arguments are specified, the script updates the shelving tracker file's timestamp to the current time,
#   effectively resetting the runtime timer.
#
# The zenity dialog will return the following exit codes that are handled internally:
#   0 : User clicked "Yes" to extend the instance runtime by 4 hours.
#   1 : User clicked "No," allowing the instance to be shelved as scheduled.
#   5 : The user did not respond within the 60-second timeout period, so no extension is applied.

set -e
set -o pipefail

if [[ ! $OSTYPE =~ ^linux ]]; then
    echo 'check-instannce-shelve.sh currently only supports Linux system.'
    exit
fi

# Define the path to the shelving instance tracker file, which stores the last extension decision.
SHEVING_INSTANCE_TRACKER_FILE=/home/exouser/shelving_instance_tracker

ASK='no'
DISPLAY='no'

# Parse command-line arguments to determine the desired action.
while getopts "ad" opt; do
  case "$opt" in
    a)
      ASK='yes'  # Flag for prompting the user to extend runtime.
      ;;
    d)
      DISPLAY='yes'  # Flag for displaying the number of hours since the last modification.
      ;;
    \?)
      >&2 echo "Unrecognized option: -$OPTARG"
      exit 1
      ;;
  esac
done

# Function to retrieve the time elapsed (in hours) since the shelving tracker file was last modified.
function retrieve_uptime_in_hours() {
  # Verify that the shelving tracker file exists.
  if [[ ! -f $SHEVING_INSTANCE_TRACKER_FILE ]]; then
    >&2 echo "Shelving tracker file not found: $SHEVING_INSTANCE_TRACKER_FILE"
    exit 1
  fi

  # Get the last-modified time of the tracker file in seconds since epoch.
  uptime_seconds=$(date -r $SHEVING_INSTANCE_TRACKER_FILE +%s)

  # Get the current time in seconds since epoch.
  current_time_seconds=$(date +%s)

  # Calculate the time difference in seconds and convert it to hours.
  uptime_diff=$((current_time_seconds - uptime_seconds))
  uptime_hours=$(echo "scale=2; $uptime_diff / 3600" | bc)

  echo $uptime_hours
}

# If the -d flag is set, display the elapsed uptime in hours.
if [[ $DISPLAY == 'yes' ]]; then
  retrieve_uptime_in_hours

# If the -a flag is set, prompt the user to extend the runtime if appropriate.
elif [[ $ASK == 'yes' ]]; then
  # Retrieve the elapsed uptime in hours.
  uptime_hours=$(retrieve_uptime_in_hours)

  # Check if uptime is between 3.5 and 4.0 hours.
  if python3 -c "exit(0 if (3.5 <= $uptime_hours <= 4.0) else 1)"; then

    # Use "zenity" to ask the user whether to extend the runtime.
    export DISPLAY=:1 && \
      zenity \
      --question \
      --timeout=300 \
      --title="Automatic Instance Shelving" \
      --text="Instance will be shelved in ~30 minutes.\n\nWould you like to keep the instance running for an additinal 4 hours?" --ok-label="Yes" --cancel-label="No"
    case $? in
      0)
        # User selected "Yes" to extend the runtime by 4 hours.
        # Update the tracker file's timestamp to 30 minutes from now, aligning with the upcoming shelving schedule.
        >&2 echo "Updating last-modified time for $SHEVING_INSTANCE_TRACKER_FILE to NOW + 30 minutes"
        touch -d "$(date -d '+30 minutes')" $SHEVING_INSTANCE_TRACKER_FILE
        ;;
      1)
        # User selected "No," allowing the instance to be shelved as scheduled.
        ;;
      5)
        # User did not respond within the timeout period.
        ;;
      *)
        # Handle unexpected zenity error codes.
        >&2 echo "Unrecognized argument zenity error code '$?'"
        exit 1
        ;;
    esac
  else
    >&2 echo "Skip asking as uptime is not between 3.5 and 4 hours"
  fi

# If no flags are set, update the shelving tracker file's timestamp to the current time.
else
  >&2 echo "Updating last-modified time for $SHEVING_INSTANCE_TRACKER_FILE to NOW"
  touch $SHEVING_INSTANCE_TRACKER_FILE
fi
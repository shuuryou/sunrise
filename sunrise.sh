#!/usr/bin/env bash

####################################
#      HARDWARE CONFIGURATION      #
####################################

# API token
TOKEN="CHANGEME"
# Hostname or IP of the gateway
DIRIGERA="CHANGEME"
# Array of lightbulb IDs
LAMPS=("CHANGEME") # Separate multiple IDs with spaces

####################################
# SUNRISE SIMULATION CONFIGURATION #
####################################

# When to turn the lamps off after simulation is complete (seconds)
auto_off=900

# Constants for the sunrise simulation
simulation_duration=30                                # Duration of sunrise simulation in minutes
steps=30                                              # Number of steps in the simulation
step_duration=$((simulation_duration * 60 / steps))   # Duration of each step in seconds

# Sunrise colors in HSL (Hue, Saturation, Lightness)
start_hue=0; start_saturation=100; start_lightness=1  # Darkroom
mid_hue=23; mid_saturation=100; mid_lightness=50      # Some sort of orange
end_hue=30; end_saturation=65; end_lightness=100      # Something that looks like daylight

####################################
#       END OF CONFIGURATION       #
####################################

interpolate() {
    local start=$1
    local mid=$2
    local end=$3
    local progress=$4
    local result=0
    local adjusted_progress

    if (( $(echo "$progress < 0.5" | bc -l) )); then
        adjusted_progress=$(echo "2 * $progress" | bc -l)
        result=$(awk "BEGIN {print $start+($mid-$start)*$adjusted_progress}")
    else
        adjusted_progress=$(echo "2 * ($progress - 0.5)" | bc -l)
        result=$(awk "BEGIN {print $mid+($end-$mid)*$adjusted_progress}")
    fi

    echo "$result"
}

turn_lamps_on() {
    for lamp in "${LAMPS[@]}"
    do
        COMMAND="[{\"attributes\":{\"isOn\":true}}]"
        curl -X PATCH "https://$DIRIGERA:8443/v1/devices/${lamp}" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$COMMAND" --insecure
    done
}

turn_lamps_off() {
    for lamp in "${LAMPS[@]}"
    do
        COMMAND="[{\"attributes\":{\"isOn\":false}}]"
        curl -X PATCH "https://$DIRIGERA:8443/v1/devices/${lamp}" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$COMMAND" --insecure
    done
}

setLightState() {
    local h=$1
    local s=$2
    local l=$3

    for lamp in "${LAMPS[@]}"
    do
        # Dirigera will not take colorHue or colorSaturation alone, only in a pair, but it
        # also won't take colorHue and colorSaturation together with lightLevel... *sigh*
        # I guess that's par for the course for an IKEA Internet of Shit device.
        #
        # My best guess is that:
        # * Both colorHue and colorSaturation are required for the Zigbee command that
        #   the gateway actually beams to the bulb.
        # * lightLevel is a separate command entirely and the gateway cannot beam two
        #   separate Zigbee commands during one PATCH request.
        #
        # So, no, you cannot combine these two requests.
        #
        # Also, there is a very short fade in/out while the bulb adjusts the color. This
        # doesn't go away if you change the other of these commands. Seems to be how the
        # bulb works, since it also does it when you use the offical IKEA app.

        COMMAND=$(printf "[{\"attributes\":{\"lightLevel\":%.0f}}]" "$l")
        curl -X PATCH "https://$DIRIGERA:8443/v1/devices/${lamp}" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$COMMAND" --insecure
        COMMAND=$(printf "[{\"attributes\":{\"colorHue\":%.15g,\"colorSaturation\":%.15g}}]" "$h" "$s")
        curl -X PATCH "https://$DIRIGERA:8443/v1/devices/${lamp}" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$COMMAND" --insecure
    done
}


prepare_sunrise_simulation() {
    # Interpolate the baseline HSL values
    current_hue=$(interpolate "$start_hue" "$mid_hue" "$end_hue" 0)
    current_saturation=$(interpolate "$(echo \"$start_saturation/100\" | bc -l)" "$(echo \"$mid_saturation/100\" | bc -l)" "$(echo \"$end_saturation/100\" | bc -l)" 0)
    current_lightness=$(interpolate "$start_lightness" "$mid_lightness" "$end_lightness" 0)

    # Set the light state
    setLightState "$current_hue" "$current_saturation" "$current_lightness"
}


perform_sunrise_simulation() {
    for ((i=0; i<=steps; i++)); do
        # Calculate progress as a percentage
        progress=$(awk "BEGIN {print $i/$steps}")

        # Interpolate the HSL values
        current_hue=$(interpolate "$start_hue" "$mid_hue" "$end_hue" "$progress")
        current_saturation=$(interpolate "$(echo \"$start_saturation/100\" | bc -l)" "$(echo \"$mid_saturation/100\" | bc -l)" "$(echo \"$end_saturation/100\" | bc -l)" "$progress")
        current_lightness=$(interpolate "$start_lightness" "$mid_lightness" "$end_lightness" "$progress")

        # Set the light state
        setLightState "$current_hue" "$current_saturation" "$current_lightness"

        # Wait for the next step
        sleep $step_duration
    done
}

# BUG: This does not work; the bulb will not process commands while soft-off
# (i.e. powered but turned off by software).
#
# Set the lights to the initial HSL values so they don't turn on to bright
# white at max brightness, or whatever they were last set to.
# prepare_sunrise_simulation

turn_lamps_on

perform_sunrise_simulation

sleep $auto_off

# As a workaround, do it here before turning the lamps off, so that at least
# people with dedicated wake-up bulbs get a win.
prepare_sunrise_simulation

turn_lamps_off


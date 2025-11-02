#!/bin/bash
#
# Auto-pause Docker containers when internet is lost,
# and unpause them when connectivity returns.
# Also adjusts CPU power profile based on state.
#
# Works great with Pi-hole + Cloudflared + WireGuard setups.

# Containers to manage
# CONTAINERS=("pihole" "wg-easy" "cloudflared" "hbbs" "hbbr")
CONTAINERS=("pihole" "wg-easy" "cloudflared")

# Timing parameters
LAST_STATE="online"
CHECK_INTERVAL=2
FAIL_COUNT=0
THRESHOLD=5            # 5 consecutive fails = ~10s offline confirmation
SUCCESS_COUNT=0
RECOVERY_THRESHOLD=1   # 1 successful ping = fast recovery

check_internet() {
    ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1
    return $?
}

check_power() {
    [[ -f /sys/class/power_supply/AC/online ]] && cat /sys/class/power_supply/AC/online || echo 1
}

set_power_profile() {
    PROFILE=$1
    if command -v cpupower >/dev/null 2>&1; then
        cpupower frequency-set -g "$PROFILE" >/dev/null 2>&1
    elif command -v tuned-adm >/dev/null 2>&1; then
        tuned-adm profile "$PROFILE" >/dev/null 2>&1
    fi
}

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

while true; do
    if check_internet; then
        ((SUCCESS_COUNT++))
        FAIL_COUNT=0
    else
        ((FAIL_COUNT++))
        SUCCESS_COUNT=0
    fi

    POWER=$(check_power)

    # CPU governor logic
    if ((FAIL_COUNT >= THRESHOLD)); then
        [[ "$POWER" -eq 0 ]] && PROFILE="powersave" || PROFILE="ondemand"
    else
        PROFILE="performance"
    fi
    set_power_profile "$PROFILE"

    # If confirmed offline
    if ((FAIL_COUNT >= THRESHOLD)) && [[ "$LAST_STATE" == "online" ]]; then
        log "[+] Internet lost (after $FAIL_COUNT fails) — pausing containers..."
        for c in "${CONTAINERS[@]}"; do
            STATE=$(docker inspect -f '{{.State.Paused}}' "$c" 2>/dev/null)
            if [[ "$STATE" == "false" ]]; then
                log " → Pausing $c"
                docker pause "$c"
            fi
        done

        if [[ "$POWER" -eq 0 ]]; then
            log "[+] On battery + no internet — suspending server."
            systemctl suspend
        fi
        LAST_STATE="offline"
    fi

    # Fast recovery when internet is back
    if ((SUCCESS_COUNT >= RECOVERY_THRESHOLD)) && [[ "$LAST_STATE" == "offline" ]]; then
        log "[+] Internet back — unpausing containers instantly..."
        for c in "${CONTAINERS[@]}"; do
            STATE=$(docker inspect -f '{{.State.Paused}}' "$c" 2>/dev/null)
            if [[ "$STATE" == "true" ]]; then
                log " → Unpausing $c"
                docker unpause "$c"
            fi
        done
        LAST_STATE="online"
    fi

    sleep $CHECK_INTERVAL
done

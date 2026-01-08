#!/bin/bash
#
# Auto-pause Docker containers when internet is lost,
# and unpause them when connectivity returns.
# Also adjusts CPU power profile based on state.
#
# Works great with Pi-hole + Cloudflared + WireGuard setups.

# Absolute paths for systemd reliability
PING="/usr/bin/ping"
CURL="/usr/bin/curl"
DOCKER="/usr/bin/docker"
SYSTEMCTL="/usr/bin/systemctl"
CPUP="cpupower"
TUNED="tuned-adm"

# Containers to manage
CONTAINERS=("pihole" "wg-easy" "cloudflared" "hbbs" "hbbr")

LAST_STATE="online"
CHECK_INTERVAL=2
FAIL_COUNT=0
SUCCESS_COUNT=0

FAIL_THRESHOLD=5         # 10 seconds offline confirmation
RECOVERY_THRESHOLD=1     # Fast recovery

# RELIABLE HOSTS ONLY (1.1.1.1 removed!)
PING_HOSTS=("8.8.8.8" "8.8.4.4" "www.google.com")
HTTP_TEST="https://www.google.com"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

check_internet() {
    # ICMP tests using absolute ping
    for HOST in "${PING_HOSTS[@]}"; do
        if $PING -c 1 -W 1 -n "$HOST" >/dev/null 2>&1; then
            return 0
        else
            log "Ping failed: $HOST"
        fi
    done

    # HTTP fallback — very reliable
    $CURL -s --max-time 2 "$HTTP_TEST" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        return 0
    fi

    return 1
}

check_power() {
    [[ -f /sys/class/power_supply/AC/online ]] && cat /sys/class/power_supply/AC/online || echo 1
}

set_power_profile() {
    PROFILE=$1
    if command -v $CPUP >/dev/null 2>&1; then
        $CPUP frequency-set -g "$PROFILE" >/dev/null 2>&1
    elif command -v $TUNED >/dev/null 2>&1; then
        $TUNED profile "$PROFILE" >/dev/null 2>&1
    fi
}

while true; do

    # Internet detection
    if check_internet; then
        ((SUCCESS_COUNT++))
        FAIL_COUNT=0
    else
        ((FAIL_COUNT++))
        SUCCESS_COUNT=0
        log "No internet detected ($FAIL_COUNT fails)"
    fi

    POWER=$(check_power)

    # CPU scaling
    if ((FAIL_COUNT >= FAIL_THRESHOLD)); then
        [[ "$POWER" -eq 0 ]] && PROFILE="powersave" || PROFILE="ondemand"
    else
        PROFILE="performance"
    fi
    set_power_profile "$PROFILE"

    # OFFLINE → PAUSE CONTAINERS
    if ((FAIL_COUNT >= FAIL_THRESHOLD)) && [[ "$LAST_STATE" == "online" ]]; then
        log "[!] Internet offline — pausing containers..."

        for c in "${CONTAINERS[@]}"; do
            STATE=$($DOCKER inspect -f '{{.State.Paused}}' "$c" 2>/dev/null)
            if [[ "$STATE" == "false" ]]; then
                log " → Pausing $c"
                $DOCKER pause "$c"
            fi
        done

        # Suspend if on battery
        if [[ "$POWER" -eq 0 ]]; then
            log "[+] On battery & offline — suspending..."
            $SYSTEMCTL suspend
        fi

        LAST_STATE="offline"
    fi

    # ONLINE → UNPAUSE CONTAINERS
    if ((SUCCESS_COUNT >= RECOVERY_THRESHOLD)) && [[ "$LAST_STATE" == "offline" ]]; then
        log "[+] Internet restored — unpausing containers..."

        for c in "${CONTAINERS[@]}"; do
            STATE=$($DOCKER inspect -f '{{.State.Paused}}' "$c" 2>/dev/null)
            if [[ "$STATE" == "true" ]]; then
                log " → Unpausing $c"
                $DOCKER unpause "$c"
            fi
        done

        LAST_STATE="online"
    fi

    sleep $CHECK_INTERVAL
done

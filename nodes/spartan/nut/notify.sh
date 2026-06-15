#!/bin/bash

# Configuration variables
LOGFILE="/var/log/nut/ups-monitor.log"
SHUTDOWN_DELAY_MINUTES=5  # Change this for testing (e.g., 1 for 1 minute)
SHUTDOWN_DELAY_SECONDS=$((SHUTDOWN_DELAY_MINUTES * 60))
CHECK_INTERVAL_SECONDS=30

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Function to check UPS status
check_ups_status() {
    upsc apcups@localhost ups.status 2>/dev/null | grep -q "OL"
}

# NUT passes notification type as environment variable, not parameter
# Handle different UPS events
NOTIFY_TYPE="${NOTIFYTYPE:-$1}"

case "$NOTIFY_TYPE" in
    "ONLINE")
        log_message "UPS EVENT: Power restored (ONLINE)"
        ;;
    "OFFLINE")
        log_message "UPS EVENT: Power lost (OFFLINE) - Starting ${SHUTDOWN_DELAY_MINUTES}-minute countdown"
        
        # Calculate how many check cycles we need
        TOTAL_CHECKS=$((SHUTDOWN_DELAY_SECONDS / CHECK_INTERVAL_SECONDS))
        
        # Wait for the specified time, but check every interval if power is restored
        for i in $(seq 1 $TOTAL_CHECKS); do
            sleep $CHECK_INTERVAL_SECONDS
            if check_ups_status; then
                log_message "Power restored during countdown, cancelling shutdown sequence"
                exit 0
            fi
            remaining=$((SHUTDOWN_DELAY_SECONDS - i * CHECK_INTERVAL_SECONDS))
            log_message "Still offline, $remaining seconds remaining until shutdown"
        done
        
        log_message "${SHUTDOWN_DELAY_MINUTES} minutes elapsed without power restoration - Beginning shutdown sequence"
        
        # Shut down all VMs
        vm_count=$(qm list | awk 'NR>1 {print $1}' | wc -l)
        if [ $vm_count -gt 0 ]; then
            log_message "Shutting down $vm_count VMs"
            for vmid in $(qm list | awk 'NR>1 {print $1}'); do
                log_message "Shutting down VM $vmid"
                qm shutdown $vmid
            done
            log_message "Waiting 60 seconds for VMs to complete shutdown"
            sleep 60
        else
            log_message "No VMs found to shutdown"
        fi
        
        # Shut down all containers
        ct_count=$(pct list | awk 'NR>1 {print $1}' | wc -l)
        if [ $ct_count -gt 0 ]; then
            log_message "Shutting down $ct_count containers"
            for ctid in $(pct list | awk 'NR>1 {print $1}'); do
                log_message "Shutting down container $ctid"
                pct shutdown $ctid
            done
            log_message "Waiting 30 seconds for containers to complete shutdown"
            sleep 30
        else
            log_message "No containers found to shutdown"
        fi
        
        # Final shutdown
        log_message "Initiating Proxmox host shutdown"
        /sbin/shutdown -h now
        ;;
    "LOWBATT")
        log_message "UPS EVENT: Low battery warning (LOWBATT)"
        ;;
    "FSD")
        log_message "UPS EVENT: Forced shutdown (FSD)"
        ;;
    *)
        log_message "UPS EVENT: Unknown event '$NOTIFY_TYPE'"
        ;;
esac

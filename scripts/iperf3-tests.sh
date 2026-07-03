#!/bin/bash
# iperf3-tests.sh — runs on the iperf3 client node (e.g. spartan)
# Measures real internal throughput to one or more iperf3 server targets
# and writes results for node_exporter's textfile collector.
#
# Prometheus text format requires all "# TYPE" declarations to appear
# before any samples for that metric name. To satisfy this, both tests
# run first and are stored in variables, then the .prom file is written
# in a single structured heredoc with all TYPE declarations grouped
# together before their respective samples.

TEXTFILE="/var/lib/node_exporter/textfile_collector/iperf3.prom"
TMPFILE="${TEXTFILE}.tmp"
LOG="/var/log/iperf3-tests.log"
TIMESTAMP=$(date +%s)

echo "$(date): Starting iperf3 tests" >> "$LOG"

# --- Run tests first, store raw JSON ---
RAW1=$(iperf3 -c "<TARGET_1_IP>" -p 5201 -J --time 10 2>/dev/null)
RAW2=$(iperf3 -c "<TARGET_2_IP>" -p 5201 -J --time 10 2>/dev/null)

# --- Parse test 1 ---
if [ -n "$RAW1" ]; then
    DOWN1=$(echo "$RAW1" | jq '.end.sum_received.bits_per_second')
    UP1=$(echo "$RAW1"   | jq '.end.sum_sent.bits_per_second')
    RT1=$(echo "$RAW1"   | jq '.end.sum_sent.retransmits')
    echo "$(date): <TARGET_1_LABEL> OK - down=$DOWN1 up=$UP1 retransmits=$RT1" >> "$LOG"
else
    DOWN1=-1; UP1=-1; RT1=-1
    echo "$(date): <TARGET_1_LABEL> FAILED" >> "$LOG"
fi

# --- Parse test 2 ---
if [ -n "$RAW2" ]; then
    DOWN2=$(echo "$RAW2" | jq '.end.sum_received.bits_per_second')
    UP2=$(echo "$RAW2"   | jq '.end.sum_sent.bits_per_second')
    RT2=$(echo "$RAW2"   | jq '.end.sum_sent.retransmits')
    echo "$(date): <TARGET_2_LABEL> OK - down=$DOWN2 up=$UP2 retransmits=$RT2" >> "$LOG"
else
    DOWN2=-1; UP2=-1; RT2=-1
    echo "$(date): <TARGET_2_LABEL> FAILED" >> "$LOG"
fi

# --- Write .prom file: all TYPE declarations before their samples ---
cat > "$TMPFILE" <<EOF
# HELP iperf3_bits_per_second Throughput in bits/sec measured by iperf3
# TYPE iperf3_bits_per_second gauge
iperf3_bits_per_second{target="<TARGET_1_LABEL>",direction="download"} $DOWN1
iperf3_bits_per_second{target="<TARGET_1_LABEL>",direction="upload"} $UP1
iperf3_bits_per_second{target="<TARGET_2_LABEL>",direction="download"} $DOWN2
iperf3_bits_per_second{target="<TARGET_2_LABEL>",direction="upload"} $UP2
# HELP iperf3_retransmits TCP retransmits during iperf3 test (indicator of lossy path)
# TYPE iperf3_retransmits gauge
iperf3_retransmits{target="<TARGET_1_LABEL>"} $RT1
iperf3_retransmits{target="<TARGET_2_LABEL>"} $RT2
# HELP iperf3_last_run_timestamp Unix timestamp of last iperf3 test run
# TYPE iperf3_last_run_timestamp gauge
iperf3_last_run_timestamp $TIMESTAMP
EOF

mv "$TMPFILE" "$TEXTFILE"

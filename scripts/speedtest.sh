#!/bin/bash
# speedtest.sh — runs on Network A node (e.g. spartan)
# Measures real ISP throughput and writes result for node_exporter's textfile collector

TEXTFILE="/var/lib/node_exporter/textfile_collector/speedtest.prom"
TMPFILE="${TEXTFILE}.tmp"
NODE="<NODE_NAME>"   # e.g. "spartan"

RESULT=$(speedtest-cli --json 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    echo "speedtest failed" >&2
    exit 1
fi

DOWNLOAD=$(echo "$RESULT" | jq '.download')
UPLOAD=$(echo "$RESULT"   | jq '.upload')
PING=$(echo "$RESULT"     | jq '.ping')
TIMESTAMP=$(date +%s)

cat > "$TMPFILE" <<EOF
# HELP speedtest_download_bits_per_second Download throughput in bits/sec
# TYPE speedtest_download_bits_per_second gauge
speedtest_download_bits_per_second{node="$NODE"} $DOWNLOAD
# HELP speedtest_upload_bits_per_second Upload throughput in bits/sec
# TYPE speedtest_upload_bits_per_second gauge
speedtest_upload_bits_per_second{node="$NODE"} $UPLOAD
# HELP speedtest_ping_latency_milliseconds ISP ping latency in ms
# TYPE speedtest_ping_latency_milliseconds gauge
speedtest_ping_latency_milliseconds{node="$NODE"} $PING
# HELP speedtest_last_run_timestamp Unix timestamp of last successful run
# TYPE speedtest_last_run_timestamp gauge
speedtest_last_run_timestamp{node="$NODE"} $TIMESTAMP
EOF

mv "$TMPFILE" "$TEXTFILE"
echo "$(date): speedtest OK - down=${DOWNLOAD} up=${UPLOAD} ping=${PING}" \
    >> /var/log/speedtest.log

#!/bin/bash
cd "$(dirname "$0")"

echo "Starting HTTP server on port 57475..."
while true
do
  echo "Listening for requests..."
  echo -e "HTTP/1.1 200 OK\n\n$(cat stats.csv)" | nc -l -k -p 57475 -q 1
  echo "Press Ctrl-C twice to stop the server."
  sleep 1
done

echo This is the netcat_client.sh
echo Type into this terminal to send things using netcat to the netcat_server.sh

while true; do
    netcat localhost 4444
    sleep 5
done


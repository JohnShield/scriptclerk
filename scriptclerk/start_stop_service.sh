echo This is an example of a script to work with Script Clerk that will start or stop a service.

echo \"sudo systemctl start apache.service\"
echo Pretending to start a service...
sleep 1

trap 'echo Script Clerk has called SIGTERM on this script; \
      echo \"sudo systemctl stop apache.service\";
      echo Pretending to stop the service...;
      echo Will autoquit in 5 seconds;
      sleep 5; exit' TERM

while true; do
    sleep 2
done


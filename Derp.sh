cd "/SPACE/Stuff/DEVEL/Derp"

# Destroy existing rails servers
if [ `cat ./tmp/pids/server.pid` -ne 0 ]
then
  kill -9 `cat ./tmp/pids/server.pid`
fi

# Launch the new one
rails server &
 
# Launch the browser
chromium-browser "http://localhost:3000"

# When the browser gets closed, kill the server
kill -9 `cat ./tmp/pids/server.pid`


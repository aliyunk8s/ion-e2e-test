#!/usr/bin/env bash
set -e
export DIR=$(dirname $0)
export ION_HOST=$(test -z "$ION_HOST" && echo 'localhost:9090' || echo "$ION_HOST")
export ION_ROOM=$(test -z "$ION_ROOM" && echo 'test-pink-video' || echo "$ION_ROOM")
export HTTP_SCHEME=$(test -z "$ION_HTTP_SCHEME" && echo 'https' || echo "$ION_HTTP_SCHEME")
export WS_SCHEME=$(test -z "$ION_WS_SCHEME" && echo 'wss' || echo "$ION_WS_SCHEME")
export ENDPOINT=$(test -z "$ENDPOINT" && echo "$WS_SCHEME://$ION_HOST/ws" || echo "$ENDPOINT")
export URL=$(test -z "$URL" && echo "$HTTP_SCHEME://$ION_HOST" || echo "$URL")

echo "Running e2e tests"
echo "Job: $JOB_ID"
echo "URL: $URL"
echo "Biz Endpoint: $ENDPOINT"
echo "Room: $ION_ROOM"
echo
echo "======================="
echo
echo "1. Joining $ION_ROOM with pink.video via go client for up to 10 minutes"

pushd $DIR
(go run join.go -d 0) &
popd

echo
echo "======================="
echo
echo "2. Launching browser and searching for hot pink..."
echo "This takes ~ 20 seconds per browser, plus browserstack queue time for MAC or IOS"
echo "Targets: $MULTI"

/usr/bin/python3 $DIR/browsertest.py | tee /data/browsertest.log

chmod -R a+r . || true

echo
echo "======================="
echo
echo "All done!"

sleep 3
PIDS=$(ps -ef | grep join | grep go-build | awk '{print $2}')
if [[ -z "$PIDS" ]]; then
    echo "No pink.video to clean up! Did the job run longer than 600 seconds?"
else
    echo "cleaning up... $PIDS"

    kill -9 $PIDS
fi

cat /data/browsertest.log | grep 'Test failed' && exit 1 || (echo "All tests passed!" && exit 0) # Die if tests failed
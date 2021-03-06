#!/usr/bin/env bash

set -e
export DIR=$(dirname $0)
export KEY="/tmp/key-$JOB_ID"
export ION_VERSION=$(test -z "$ION_VERSION" && echo 'master' || echo "$ION_VERSION")
export WEB_VERSION=$(test -z "$WEB_VERSION" && echo 'master' || echo "$WEB_VERSION")

test -z "$JOB_ID" && (echo "Error: set JOB_ID variable" && exit 1)
test -z "$DOMAIN" && (echo "Error: set DOMAIN variable" && exit 1)
test -z "$EMAIL" && (echo "Error: set EMAIL variable" && exit 1)

# Generate SSH keys for session
if [[ ! -e $KEY ]] ; then 
    ssh-keygen -t rsa -b 2048 -N '' -f $KEY &>/dev/null
fi

export TF_VAR_SSH_PUBLIC_KEY=$(cat $KEY.pub)
export TF_VAR_JOB_ID=$JOB_ID
echo "Applying terraform..."
pushd $DIR
terraform init || true
terraform apply -auto-approve
cp terraform.tfstate /data || true
export IP=$(terraform output ip)
popd


SSH_ARGS="-o StrictHostKeyChecking=no -i $KEY"
SSH="ssh $SSH_ARGS root@$IP"

# Backoff algorithm, will wait 1, 2, ... 7 seconds between tries
NEXT_WAIT_TIME=0
MAX_WAIT_TIME=7
until [ $NEXT_WAIT_TIME -eq $MAX_WAIT_TIME ] || $SSH "whoami"; do
    echo "Waiting for ssh, sleeping $((++NEXT_WAIT_TIME))..."
    sleep $NEXT_WAIT_TIME
done
[ $NEXT_WAIT_TIME -lt $MAX_WAIT_TIME ] || (echo "Unable to connect to $IP on ssh..." && exit 1)

echo "Uploading cluster files..."
scp $SSH_ARGS -r $DIR/cluster root@$IP:/

$SSH "bash /cluster/bootstrap.sh '$DOMAIN' '$EMAIL' '$ION_VERSION' '$WEB_VERSION'"

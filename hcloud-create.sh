#! /usr/bin/env nix-shell
#! nix-shell -i bash -p cloud-init -p hcloud -p openssl -p openssh -p curl -p netcat
set -e

SERVER_NAME=a
SERVER_TYPE=cpx11
#SERVER_TYPE=cpx31
LOCATION=nbg1
IMAGE=debian-11
#SSH_KEY=user@personal-hetzner
USER_DATA_FILE=hcloud-user-data.yml

eval "$@"

if [ "$SERVER_TYPE" == "?" ] ; then
  hcloud server-type list
  exit 2
fi
if [ "$LOCATION" == "?" ] ; then
  hcloud location list
  exit 2
fi
#if [ "$SSH_KEY" == "?" ] ; then
#  hcloud ssh-key list
#  exit 2
#fi

#if [ -z "$(hcloud context active)" ] ; then ...  -> hcloud already shows a good error message

cloud-init schema --annotate -c hcloud-user-data.yml

if [ ! -e ".servers/id_rsa" ] ; then
  mkdir -p .servers
  ssh-keygen -t rsa -b 4096 -f .servers/id_rsa -N ""
fi
SSH_KEY=auto-$(sha1sum .servers/id_rsa.pub | cut -f1 -d" ")
if ! hcloud ssh-key describe "$SSH_KEY" >/dev/null ; then
  hcloud ssh-key create --name "$SSH_KEY" --public-key-from-file .servers/id_rsa.pub
fi

# add shared secret to config
CFG=$(umask 077; mktemp)
cleanup() {
  rm -f "$CFG"
}
trap cleanup EXIT INT QUIT TERM
cat "$USER_DATA_FILE" >$CFG
SECRET=$(openssl rand -base64 40)
echo "- path: /etc/ssh-shared-secret" >>$CFG
echo "  content: '$SECRET'" >>$CFG
echo "  permissions: '0600'" >>$CFG
cloud-init schema --annotate -c $CFG

hcloud server create --location "$LOCATION" --image "$IMAGE" --ssh-key "$SSH_KEY" --name "$SERVER_NAME" --type "$SERVER_TYPE" --user-data-from-file $CFG
IP=$(hcloud server ip "$SERVER_NAME")

rm -f ".servers/$SERVER_NAME/"{known_hosts,config}
mkdir -p ".servers/$SERVER_NAME"
cat >".servers/$SERVER_NAME/config" <<EOF
Host server $SERVER_NAME
  HostName $IP
  User root
  IdentitiesOnly yes
  IdentityFile `pwd`/.servers/id_rsa
  PubkeyAuthentication yes
  PasswordAuthentication no
  HostKeyAlias x#
  UserKnownHostsFile `pwd`/.servers/$SERVER_NAME/known_hosts
EOF
( umask 077; echo "$SECRET" >".servers/$SERVER_NAME/ssh-shared-secret" )

echo "Waiting for server to be reachable on port 36431..."
for _ in $(seq 500) ; do
  #if curl -o ".servers/$SERVER_NAME/ssh-server-pubkey" "http://$IP:36431/ssh-server-pubkey" &>/dev/null ; then
  if nc -w 10 "$IP" 36431 2>/dev/null >".servers/$SERVER_NAME/keys.tar" </dev/null ; then
    break
  else
    rm -f ".servers/$SERVER_NAME/keys.tar"
    echo -n .
    sleep 2
  fi
done
if [ ! -e ".servers/$SERVER_NAME/keys.tar" ] ; then
  # debug: connect to Debian via SSH and run: journalctl -f --unit cloud-final
  echo "Timeout." >&2
  exit 3
fi
#curl -o ".servers/$SERVER_NAME/ssh-server-pubkey.sig" "http://$IP:1234/ssh-server-pubkey.sig"

tar -C ".servers/$SERVER_NAME" -xf ".servers/$SERVER_NAME/keys.tar" host-keys host-keys.sig

EXPECTED="$(openssl dgst -sha256 -hmac <(echo "$SECRET") -binary <".servers/$SERVER_NAME/host-keys" | openssl enc -base64 -A)"
ACTUAL="$(cat ".servers/$SERVER_NAME/host-keys.sig")"
if [ "$EXPECTED" != "$ACTUAL" ] ; then
  echo "Invalid HMAC for SSH host key." >&2
  exit 3
fi

sed -n 's/^\(ssh-[-a-z0-9]\+ \+[A-Za-z0-9+\/=]\+\) .*$/x# \1/p' <".servers/$SERVER_NAME/host-keys" >".servers/$SERVER_NAME/known_hosts"

ssh -F ".servers/$SERVER_NAME/config" server -- true


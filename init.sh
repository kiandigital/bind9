#!/bin/sh

#
# Script options (exit script on command fail).
#
# set -e


update_zones(){
  truncate -s 0 /tmp/zones
  for z in $(ls -1  /etc/bind/*.zone); do 
    zone=$(basename $z | sed "s|\.zone$||")
    cat >>/tmp/zones <<EOL
    zone "${zone}" IN {
      type master;
      file "/etc/bind/${zone}.zone";
    };
EOL
  done
  mv /tmp/zones /tmp/automated.zones
}

watch_config(){
  PID=$(ps aux | grep named | grep -v grep | awk '{print $1}')
  echo "PID: $PID"
  CONFIG_HASH=$(md5sum /etc/bind/* | paste -s -d ' ' | md5sum | awk '{print $1}')
  while true ; do
    sleep 10
    update_zones
    CONFIG_HASH_NEW=$(md5sum /etc/bind/* | paste -s -d ' ' | md5sum | awk '{print $1}')
    [ "$CONFIG_HASH" = "$CONFIG_HASH_NEW" ] || kill -1 $PID 
    CONFIG_HASH="$CONFIG_HASH_NEW"
  done
}

#
# Define default Variables.
#
USER="named"
GROUP="named"
COMMAND_OPTIONS_DEFAULT="-f"
NAMED_UID_DEFAULT="1000"
NAMED_GID_DEFAULT="101"
COMMAND="/usr/sbin/named -u ${USER} -c /etc/bind/named.conf ${COMMAND_OPTIONS:=${COMMAND_OPTIONS_DEFAULT}}"

NAMED_UID_ACTUAL=$(id -u ${USER})
NAMED_GID_ACTUAL=$(id -g ${GROUP})

update_zones
#
# Display settings on standard out.
#
echo "named settings"
echo "=============="
echo
echo "  Username:        ${USER}"
echo "  Groupname:       ${GROUP}"
echo "  UID actual:      ${NAMED_UID_ACTUAL}"
echo "  GID actual:      ${NAMED_GID_ACTUAL}"
echo "  UID prefered:    ${NAMED_UID:=${NAMED_UID_DEFAULT}}"
echo "  GID prefered:    ${NAMED_GID:=${NAMED_GID_DEFAULT}}"
echo "  Command:         ${COMMAND}"
echo

#
# Change UID / GID of named user.
#
echo "Updating UID / GID... "
if [ ${NAMED_GID_ACTUAL} -ne ${NAMED_GID} -o ${NAMED_UID_ACTUAL} -ne ${NAMED_UID} ]
then
    echo "change user / group"
    deluser ${USER}
    addgroup -g ${NAMED_GID} ${GROUP}
    adduser -u ${NAMED_UID} -G ${GROUP} -g 'Linux User named' -s /sbin/nologin -D ${USER}
    echo "[DONE]"
    echo "Set owner and permissions for old uid/gid files"
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -user ${NAMED_UID_ACTUAL} -exec chown ${USER} {} \;
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -group ${NAMED_GID_ACTUAL} -exec chgrp ${GROUP} {} \;
    echo "[DONE]"
else
    echo "[NOTHING DONE]"
fi

#
# Checking config
#
echo "Checking config ..."
/usr/sbin/named-checkconf /etc/bind/named.conf

#
# Start named.
#
echo "Start named... " 
${COMMAND} 2>&1 &

#
# Checking config
#
echo "Watch config ..."
watch_config 
#!/bin/bash
MACHINE=$1

multipass exec ${MACHINE?} -- sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update < /dev/null > /dev/null
multipass exec ${MACHINE?} -- sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade < /dev/null > /dev/null
multipass exec ${MACHINE?} -- sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade < /dev/null > /dev/null
multipass exec ${MACHINE?} -- sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" autoremove < /dev/null > /dev/null

if multipass exec ${MACHINE?} -- [ -e /var/run/reboot-required ]; then
  multipass restart ${MACHINE?}
  ./update.sh ${MACHINE?}
fi

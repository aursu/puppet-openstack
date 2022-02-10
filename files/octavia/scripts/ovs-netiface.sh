#!/bin/bash
# https://github.com/openstack/neutron/blob/master/devstack/lib/octavia

MGMT_PORT_ID=${MGMT_PORT_ID:-$1}
MAC=${MGMT_PORT_MAC:-$2}

OVS_BRIDGE=${OVS_BRIDGE:-br-int}
BRNAME=${BRNAME:-o-hm0}

[ -n "$MGMT_PORT_ID" -a -n "$MAC" ] || exit 1

ovs-vsctl -- \
    --may-exist add-port $OVS_BRIDGE $BRNAME -- \
    set Interface $BRNAME type=internal -- \
    set Interface $BRNAME external-ids:iface-status=active -- \
    set Interface $BRNAME external-ids:attached-mac=$MAC -- \
    set Interface $BRNAME external-ids:iface-id=$MGMT_PORT_ID -- \
    set Interface $BRNAME external-ids:skip_cleanup=true
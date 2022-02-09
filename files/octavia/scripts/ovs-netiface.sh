#!/bin/bash

MGMT_PORT_ID=${MGMT_PORT_ID:-$1}
MGMT_PORT_MAC=${MGMT_PORT_MAC:-$2}

OVS_BRIDGE=${OVS_BRIDGE:-br-int}
INTERFACE=${INTERFACE:-o-hm0}

[ -n "$MGMT_PORT_ID" -a -n "$MGMT_PORT_MAC" ] || exit 1

ovs-vsctl -- \
    --may-exist add-port $OVS_BRIDGE $INTERFACE -- \
    set Interface $INTERFACE type=internal -- \
    set Interface $INTERFACE external-ids:iface-status=active -- \
    set Interface $INTERFACE external-ids:attached-mac=$MGMT_PORT_MAC -- \
    set Interface $INTERFACE external-ids:iface-id=$MGMT_PORT_ID -- \
    set Interface $INTERFACE external-ids:skip_cleanup=true
#!/bin/bash

source /root/octavia_disk_image_create/bin/activate
/root/octavia/diskimage-create/diskimage-create.sh "$@"
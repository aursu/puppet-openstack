FROM ubuntu:bionic

USER root

# Create the amphora image
# https://docs.openstack.org/octavia/latest/admin/amphora-image-build.html
RUN apt-get update && apt-get install -y \
      curl \
      debootstrap \
      git \
      grub-common \
      kpartx \
      lsb-release \
      python-pip \
      python-virtualenv \
      qemu-utils \
      sudo \
    && pip install --upgrade pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

RUN virtualenv octavia_disk_image_create \
    && git clone https://opendev.org/openstack/octavia.git \
    && mkdir -p /root/octavia/diskimage-create/images

WORKDIR /root/octavia/diskimage-create

RUN pip install -r requirements.txt

VOLUME [ "/root/octavia/diskimage-create/images" ]

ENTRYPOINT ["/root/docker-entrypoint.sh"]
CMD ["-o", "amphora-x64-haproxy.qcow2"]
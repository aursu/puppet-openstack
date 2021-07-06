## Server setup

```
openstack --os-compute-api-version 2.74 server create --flavor m1.small2 \
    --nic net-id=b6744bc4-4034-4028-abf3-71a3e19d144a,v4-fixed-ip=172.16.100.49 \
    --volume=ef6c83e8-b7bb-4f70-9f0f-01ae051e263a \
    --host=dev-web-005.intern.crytek.de \
    --security-group a32b794b-aeb7-4e3c-9a61-907deeb2c8be --security-group 8efb4230-5534-4e74-a8e9-63ac226104d8 \
    --key-name cloud-images kubec-01

openstack --os-compute-api-version 2.74 server create --flavor m1.large4 \
    --nic net-id=b6744bc4-4034-4028-abf3-71a3e19d144a,v4-fixed-ip=172.16.100.139 \
    --volume=80cc0962-62af-4989-84b2-e22a799bfa88 \
    --host=dev-web-004.intern.crytek.de \
    --security-group a32b794b-aeb7-4e3c-9a61-907deeb2c8be --security-group 8efb4230-5534-4e74-a8e9-63ac226104d8 \
    --key-name cloud-images kube-01
```

## Server migration (cold)

```
openstack server migrate --os-compute-api-version 2.56 --host dev-web-006.intern.crytek.de kube-poc5
```

### [Live-migrate instances](https://docs.openstack.org/nova/queens/admin/live-migration-usage.html)

* [Configure live migrations](https://docs.openstack.org/nova/queens/admin/configuring-migrations.html#section-configuring-compute-migrations)

## Errors

### 1
```
Notice: /Stage[main]/Openstack::Controller::Networking/Openstack_subnet[provider]/dns_nameserver: dns_nameserver changed ['10.100.0.30', '10.100.0.10', '10.100.0.20'] to ['10.100.0.30']
Debug: Executing: '/usr/bin/openstack subnet set --dns-nameserver 10.100.0.30 provider'
Debug: Execution of /usr/bin/openstack command failed: Execution of '/usr/bin/openstack subnet set --dns-nameserver 10.100.0.30 provider' returned 1: BadRequestException: 400: Client Error for url: http://controller:9696/v2.0/subnets/fad5597b-cd4e-4753-803b-f868a3120cc2, Invalid input for dns_nameservers. Reason: Duplicate nameserver '10.100.0.30'.
```

### 2
```
Warning: Openstack_image[amphora-x64-haproxy](provider=glance): Image file is not specified or does not exist
Notice: /Stage[main]/Openstack::Octavia::Amphora/Openstack_image[amphora-x64-haproxy]/ensure: created
```

### 3
```
Debug: Executing: '/usr/bin/openstack --os-project-name service --os-username octavia --os-password ****** security group create -f json --project service --project-domain default lb-mgmt-sec-grp'
Debug: Execution of /usr/bin/openstack command failed: Execution of '/usr/bin/openstack --os-project-name service --os-username octavia --os-password ****** security group create -f json --project service --project-domain default lb-mgmt-sec-grp' returned 1: Error while executing command: ConflictException: 409, Quota exceeded for resources: ['security_group'].
Notice: /Stage[main]/Openstack::Controller::Octavia/Openstack_security_group[service/lb-mgmt-sec-grp]/ensure: created
Debug: /Stage[main]/Openstack::Controller::Octavia/Openstack_security_group[service/lb-mgmt-sec-grp]: The container Class[Openstack::Controller::Octavia] will propagate my refresh event
Debug: Executing: '/usr/bin/openstack --os-project-name service --os-username octavia --os-password ****** security group create -f json --project service --project-domain default lb-health-mgr-sec-grp'
Debug: Execution of /usr/bin/openstack command failed: Execution of '/usr/bin/openstack --os-project-name service --os-username octavia --os-password ****** security group create -f json --project service --project-domain default lb-health-mgr-sec-grp' returned 1: Error while executing command: ConflictException: 409, Quota exceeded for resources: ['security_group'].
Notice: /Stage[main]/Openstack::Controller::Octavia/Openstack_security_group[service/lb-health-mgr-sec-grp]/ensure: created
Debug: /Stage[main]/Openstack::Controller::Octavia/Openstack_security_group[service/lb-health-mgr-sec-grp]: The container Class[Openstack::Controller::Octavia] will propagate my refresh event
Debug: Prefetching openstack resources for openstack_security_rule
```

#### Resolution

```
openstack quota set --secgroups 100 service
```

### 4

```
Debug: Executing: '/usr/bin/openstack port show -f json 017763ad-75a4-40f6-bd6a-6ac82f8520cb'
Notice: /Stage[main]/Openstack::Controller::Octavia/Openstack_port[octavia-health-manager-listen-port]/enabled: enabled changed 'false' to 'true'
Debug: Executing: '/usr/bin/openstack --os-project-name service --os-username octavia --os-password ****** port set --enable --enable-port-security 017763ad-75a4-40f6-bd6a-6ac82f8520cb'
```

### 5

During migration (but not critical)

```
2021-04-27 06:34:42.708 3032374 ERROR neutron.agent.linux.utils [req-0d3393e8-dcb1-4f29-90fe-dbc974a021ef - - - - -] Exit code: 255; Cmd: ['bridge', 'fdb', 'delete', 'fa:16:3e:5a:18:a0', 'dev', 'vxlan-1', 'dst', '10.100.16.9']; Stdin: ; Stdout: ; Stderr: RTNETLINK answers: No such file or directory
```

### 6
```
2021-04-27 14:16:54.433 1452266 WARNING oslo_policy.policy [req-fe05fa37-6441-4556-b88b-715b3c0946be ce4381203b03447a89820d9b0ec2526b d575daeadf144225aa7a53db2124b68b - default default] JSON formatted policy_file support is deprecated since Victoria release. You need to use YAML format which will be default in future. You can use ``oslopolicy-convert-json-to-yaml`` tool to convert existing JSON-formatted policy file to YAML-formatted in backward compatible way: https://docs.openstack.org/oslo.policy/latest/cli/oslopolicy-convert-json-to-yaml.html.
```

### 7
```
==> /var/log/neutron/server.log <==
2021-04-27 14:16:55.129 1454062 WARNING keystonemiddleware.auth_token [-] A valid token was submitted as a service token, but it was not a valid service token. This is incorrect but backwards compatible behaviour. This will be removed in future releases.
```

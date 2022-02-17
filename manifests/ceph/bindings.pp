# @summary Python bindings for librbd
#
# Python bindings for librbd
#
# @example
#   include openstack::ceph::bindings
class openstack::ceph::bindings {
  # both  CentOS  and Ubuntu have python3-rbd
  package { 'python3-rbd':
    ensure => present,
  }
}

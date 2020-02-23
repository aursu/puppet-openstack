# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::djangoconfig { 'namevar': }
define openstack::djangoconfig (
  Hash[
    String,
    Variant[
      String,
      Struct[{
        value             => String,
        Optional[ensure]  => Enum[present, absent],
        Optional[require] => Type,
        Optional[notify]  => Type,
        Optional[after]   => String
      }]
    ], 1] $content,
  String  $path = $name
)
{
  $content.each | String $key, $value | {
    $attributes = $value ? {
      String  => { value => $value },
      default => $value
    }

    djangosetting {
      default:
        ensure => present,
        config => $path,
      ;
      "${path}/${key}": * => $attributes;
    }
  }
}

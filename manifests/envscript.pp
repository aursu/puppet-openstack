# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::envscript { 'namevar': }
define openstack::envscript (
  Hash[ String,
    Variant[ String,
      Struct[{
        value             => String,
        Optional[ensure]  => Enum[present, absent],
        Optional[require] => Type,
        Optional[path]    => Stdlib::Unixpath
      }]
    ], 1 ]  $content,
  String    $path     = $name,
)
{
  $content.each | String $location, $value | {
    $attributes = $value ? {
      String  => { value => $value },
      default => $value
    }
    if $location =~ /^export/ {
      $export_location = $location
    }
    else {
      $export_location = "export ${location}"
    }
    ini_setting {
      "${path}/${location}":  * => { setting => $export_location } + $attributes;
      default:    * => {
        ensure            => present,
        section           => '',
        key_val_separator => '=',
        path              => $path,
      };
    }
  }
}

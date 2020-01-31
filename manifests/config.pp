# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::config { 'namevar': }
define openstack::config (
  Hash[ String,
    Variant[ String,
      Struct[{
        value                       => String,
        Optional[ensure]            => Enum[present, absent],
        Optional[path]              => Stdlib::Unixpath,
        Optional[key_val_separator] => String,
        Optional[section_prefix]    => String,
        Optional[section_suffix]    => String,
        Optional[indent_char]       => String,
        Optional[indent_width]      => Integer,
        Optional[require]           => Type,
        Optional[notify]            => Type,
      }]
    ], 1 ]  $content,
    Stdlib::Unixpath
            $path = $name,
)
{
  $content.each | String $key, $value | {
    if '/' in $key {
        $location = split($key, '/')
    }
    else {
        $location = [ '', $key ]
    }

    $attributes = $value ? {
        String  => { value => $value },
        default => $value
    }

    ini_setting {
      default:
        * => {
          ensure => present,
          path   =>  $path,
        };
      "${path}/${key}":
        * => {
          section => $location[0],
          setting => $location[1]
        } + $attributes;
    }
  }
}

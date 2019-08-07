# Define: supervisord::eventlistener
#
# This define creates an eventlistener configuration file
#
# Documentation on parameters available at:
# http://supervisord.org/configuration.html#eventlistener-x-section-settings
#
define supervisord::eventlistener(
  String $command,
  $ensure                                                = present,
  Enum['running',
    'stopped',
    'removed',
    'unmanaged'] $ensure_process                         = 'running',
  Boolean $cfgreload                                     = false,
  Integer $buffer_size                                   = 10,
  Array $events                                          = [],
  String $result_handler                                 = '',
  $env_var                                               = undef,
  $process_name                                          = undef,
  Integer $numprocs                                      = 1,
  Optional[Integer] $numprocs_start                      = undef,
  Optional[Variant[Integer, Pattern[/^\d+$/]]] $priority = undef,
  Optional[Boolean] $autostart                           = undef,
  Optional[Variant[
    Boolean, Enum['true',
      'false',
      'unexpected']]] $autorestart                       = undef,
  Optional[Integer] $startsecs                           = undef,
  Optional[Integer] $startretries                        = undef,
  String $exitcodes                                      = '',
  Optional[Enum['TERM',
    'HUP',
    'INT',
    'QUIT',
    'KILL',
    'USR1',
    'USR2']] $stopsignal                                 = undef,
  Optional[Integer] $stopwaitsecs                        = undef,
  Optional[Boolean] $stopasgroup                         = undef,
  Optional[Boolean] $killasgroup                         = undef,
  String $user                                           = '',
  Optional[Boolean] $redirect_stderr                     = undef,
  String $stdout_logfile                                 = "eventlistener_${name}.log",
  String $stdout_logfile_maxbytes                        = '',
  Optional[Integer] $stdout_logfile_backups              = undef,
  Optional[Boolean] $stdout_events_enabled               = undef,
  String $stderr_logfile                                 = "eventlistener_${name}.error",
  String $stderr_logfile_maxbytes                        = '',
  Optional[Integer] $stderr_logfile_backups              = undef,
  Optional[Boolean] $stderr_events_enabled               = undef,
  Optional[Hash] $environment                            = undef,
  Optional[Hash] $event_environment                      = undef,
  Optional[Stdlib::Absolutepath] $directory              = undef,
  Optional[Pattern[/^[0-7][0-7][0-7]$/]] $umask          = undef,
  Optional[Stdlib::HTTPUrl] $serverur                    = undef,
  Stdlib::Filemode $config_file_mode                     = '0644'
) {

  include supervisord

  # create the correct log variables
  $stdout_logfile_path = $stdout_logfile ? {
        /(NONE|AUTO|syslog)/ => $stdout_logfile,
        /^\//                => $stdout_logfile,
        default              => "${supervisord::log_path}/${stdout_logfile}",
  }

  $stderr_logfile_path = $stderr_logfile ? {
        /(NONE|AUTO|syslog)/ => $stderr_logfile,
        /^\//                => $stderr_logfile,
        default              => "${supervisord::log_path}/${stderr_logfile}",
  }

  # Handle deprecated $environment variable
  if $environment { notify {'[supervisord] *** DEPRECATED WARNING ***: $event_environment has replaced $environment':}}
  $_event_environment = $event_environment ? {
    undef   => $environment,
    default => $event_environment
  }

  # convert environment data into a csv
  if $env_var {
    $env_hash = lookup($env_var, {
      value_type => Hash,
      merge      => 'hash',
    })
    $env_string = hash2csv($env_hash)
  } elsif $_event_environment {
    $env_string = hash2csv($_event_environment)
  }

  # Reload default with override
  $_cfgreload = $cfgreload ? {
    undef   => $supervisord::cfgreload_eventlistener,
    default => $cfgreload
  }

  if ! empty($events) {
    $events_string = array2csv($events)
  }

  $conf = "${supervisord::config_include}/eventlistener_${name}.conf"

  file { $conf:
    ensure  => $ensure,
    owner   => 'root',
    mode    => $config_file_mode,
    content => template('supervisord/conf/eventlistener.erb'),
  }

  if $_cfgreload {
    File[$conf] {
      notify => Class['supervisord::reload'],
    }
  }

  case $ensure_process {
    'stopped': {
      supervisord::supervisorctl { "stop_${name}":
        command => 'stop',
        process => $name
      }
    }
    'removed': {
      supervisord::supervisorctl { "remove_${name}":
        command => 'remove',
        process => $name
      }
    }
    'running': {
      supervisord::supervisorctl { "start_${name}":
        command => 'start',
        process => $name,
        unless  => 'running'
      }
    }
    default: { }
  }
}

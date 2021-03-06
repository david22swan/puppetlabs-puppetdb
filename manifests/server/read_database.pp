# PRIVATE CLASS - do not use directly
class puppetdb::server::read_database (
  $database               = $puppetdb::params::read_database,
  $database_host          = $puppetdb::params::read_database_host,
  $database_port          = $puppetdb::params::read_database_port,
  $database_username      = $puppetdb::params::read_database_username,
  $database_password      = $puppetdb::params::read_database_password,
  $database_name          = $puppetdb::params::read_database_name,
  $jdbc_ssl_properties    = $puppetdb::params::read_database_jdbc_ssl_properties,
  $database_validate      = $puppetdb::params::read_database_validate,
  $log_slow_statements    = $puppetdb::params::read_log_slow_statements,
  $conn_max_age           = $puppetdb::params::read_conn_max_age,
  $conn_keep_alive        = $puppetdb::params::read_conn_keep_alive,
  $conn_lifetime          = $puppetdb::params::read_conn_lifetime,
  $confdir                = $puppetdb::params::confdir,
  $puppetdb_user          = $puppetdb::params::puppetdb_user,
  $puppetdb_group         = $puppetdb::params::puppetdb_group,
  $database_max_pool_size = $puppetdb::params::read_database_max_pool_size,
) inherits puppetdb::params {

  # Only add the read database configuration if database host is defined.
  if $database_host != undef {
    if str2bool($database_validate) {
      # Validate the database connection.  If we can't connect, we want to fail
      # and skip the rest of the configuration, so that we don't leave puppetdb
      # in a broken state.
      #
      # NOTE:
      # Because of a limitation in the postgres module this will break with
      # a duplicate declaration if read and write database host+name are the
      # same.
      class { 'puppetdb::server::validate_read_db':
        database          => $database,
        database_host     => $database_host,
        database_port     => $database_port,
        database_username => $database_username,
        database_password => $database_password,
        database_name     => $database_name,
      }
    }

    $read_database_ini = "${confdir}/read_database.ini"

    file { $read_database_ini:
      ensure => file,
      owner  => $puppetdb_user,
      group  => $puppetdb_group,
      mode   => '0600',
    }

    $file_require = File[$read_database_ini]
    $ini_setting_require = str2bool($database_validate) ? {
      false   => $file_require,
      default => [$file_require, Class['puppetdb::server::validate_read_db']],
    }
    # Set the defaults
    Ini_setting {
      path    => $read_database_ini,
      ensure  => present,
      section => 'read-database',
      require => $ini_setting_require,
    }

    if $database == 'postgres' {
      $classname = 'org.postgresql.Driver'
      $subprotocol = 'postgresql'

      if !empty($jdbc_ssl_properties) {
        $database_suffix = $jdbc_ssl_properties
      }
      else {
        $database_suffix = ''
      }

      $subname = "//${database_host}:${database_port}/${database_name}${database_suffix}"

      ini_setting { 'puppetdb_read_database_username':
        setting => 'username',
        value   => $database_username,
      }

      if $database_password != undef {
        ini_setting { 'puppetdb_read_database_password':
          setting => 'password',
          value   => $database_password,
        }
      }
    }

    ini_setting { 'puppetdb_read_classname':
      setting => 'classname',
      value   => $classname,
    }

    ini_setting { 'puppetdb_read_subprotocol':
      setting => 'subprotocol',
      value   => $subprotocol,
    }

    ini_setting { 'puppetdb_read_pgs':
      setting => 'syntax_pgs',
      value   => true,
    }

    ini_setting { 'puppetdb_read_subname':
      setting => 'subname',
      value   => $subname,
    }

    ini_setting { 'puppetdb_read_log_slow_statements':
      setting => 'log-slow-statements',
      value   => $log_slow_statements,
    }

    ini_setting { 'puppetdb_read_conn_max_age':
      setting => 'conn-max-age',
      value   => $conn_max_age,
    }

    ini_setting { 'puppetdb_read_conn_keep_alive':
      setting => 'conn-keep-alive',
      value   => $conn_keep_alive,
    }

    ini_setting { 'puppetdb_read_conn_lifetime':
      setting => 'conn-lifetime',
      value   => $conn_lifetime,
    }

    if $puppetdb::params::database_max_pool_size_setting_name != undef {
      if $database_max_pool_size == 'absent' {
        ini_setting { 'puppetdb_read_database_max_pool_size':
          ensure  => absent,
          setting => $puppetdb::params::database_max_pool_size_setting_name,
        }
      } elsif $database_max_pool_size != undef {
        ini_setting { 'puppetdb_read_database_max_pool_size':
          setting => $puppetdb::params::database_max_pool_size_setting_name,
          value   => $database_max_pool_size,
        }
      }
    }
  } else {
    file { "${confdir}/read_database.ini":
      ensure => absent,
    }
  }
}

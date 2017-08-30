package {'sensu': ensure => present }
package {'nagios-plugins-http': ensure => present }
package {'nagios-plugins-load': ensure => present }
package {'nagios-plugins-disk': ensure => present }
package {'nagios-plugins-procs': ensure => present }
package {'nagios-plugins-users': ensure => present }
package {'nagios-plugins-uptime': ensure => present }
package {'nagios-plugins-sensors': ensure => present }


file {'/etc/sensu/conf.d/rabbitmq.json':
   ensure => present,
   content => '{
  "rabbitmq": {
    "host": "monitor",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret"
  }
}',
  require => Package['sensu'],
  notify  => Service['sensu-client'],
}

file { '/etc/sensu/conf.d/client.json':
  ensure => present,
  content => '{
  "client": {
    "name": "this-client",
    "address": "10.11.12.13",
    "environment": "development",
    "subscriptions": [
      "rhel",
      "bldsrv"
    ]
  }
}',
  require => Package['sensu'],
  notify  => Service['sensu-client'],
}

file { '/usr/lib/systemd/system/sensu-client.service':
  ensure  => present,
  source  => '/usr/share/sensu/systemd/sensu-client.service',
  require => [
              Package['sensu'],
              File['/etc/sensu/conf.d/client.json'],
             ],
}
service { 'sensu-client':
  ensure  => running,
  enable  => true,
  require => File['/usr/lib/systemd/system/sensu-client.service'],
}


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

#    "address": "<%= @ipaddress_enp3s0f0 =%>",
$client_json_template = @(END)
{
  "client": {
    "name": "<%= @hostname %>",
    "address": "<%= @ipaddress_enp3s0f0 %>",
    "environment": "development",
    "subscriptions": [
      "rhel",
      "bldsrv"
    ]
  }
}
END

file { '/etc/sensu/conf.d/client.json':
  ensure => present,
  content => inline_template($client_json_template),
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


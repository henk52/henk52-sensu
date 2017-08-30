# See: https://sensuapp.org/docs/latest/install-redis-on-rhel-centos
package { 'redis': ensure => present }

service { 'redis':
  ensure  => running,
  enable  => true,
  require => Package['redis'],
}

# Verify with: redis-cli ping
# replies: PONG


# for the sensu pkg, please see:
#  See: https://core.sensuapp.com/yum/x86_64/sensu-0.22.0-1.x86_64.rpm
#  at: https://sensuapp.org/download


package { 'sensu': ensure => present }

file { '/etc/sensu/conf.d/redis.json':
  ensure => present,
  content => '{
  "redis": {
    "host": "127.0.0.1",
    "port": 6379,
    "auto_reconnect": true
  }
}',
  require => Package['sensu'],
  notify  => Service['redis'],
}

# Installing RabbitMQ as the default transport for sensu.
#  https://sensuapp.org/docs/0.29/installation/install-rabbitmq-on-rhel-centos.html
package {'rabbitmq-server': ensure => present }
service { 'rabbitmq-server':
  ensure  => running,
  enable  => true,
  require => Package['rabbitmq-server'],
}

# TODO V Find a way to automate the execution of these commands.
# sudo rabbitmqctl add_vhost /sensu
# sudo rabbitmqctl add_user sensu secret
# sudo rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"
# rabbitmqctl status

# Seems to affect the file
#   /var/lib/rabbitmq/mnesia/rabbit@zcmonitor/rabbit_vhost.DCL

file {'/etc/sensu/conf.d/rabbitmq.json':
   ensure => present,
   content => '{
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret"
  }
}',
  require => Package['sensu'],
}

# Using redis as the sensu transport.
file { '/etc/sensu/conf.d/transport.json':
  ensure => present,
  content => '{
  "transport": {
    "name": "rabbitmq",
    "reconnect_on_error": true
  }
}',
  require => Package['sensu'],
  notify  => Service['sensu-server'],
}
# TODO V Which services should be notified about this change?


file { '/usr/lib/systemd/system/sensu-server.service':
  ensure  => present,
  source  => '/usr/share/sensu/systemd/sensu-server.service',
  require => Package['sensu'],
}
service { 'sensu-server':
  ensure  => running,
  enable  => true,
  require => File['/usr/lib/systemd/system/sensu-server.service'],
}

# https://sensuapp.org/docs/0.29/platforms/sensu-on-rhel-centos.html#sensu-core

# /etc/sensu/conf.d/api.json
file { '/etc/sensu/conf.d/api.json':
  ensure => present,
  content => '{
  "api": {
    "host": "localhost",
    "bind": "0.0.0.0",
    "port": 4567
  }
}',
  require => Package['sensu'],
  notify  => Service['sensu-api'],
}

file { '/usr/lib/systemd/system/sensu-api.service':
  ensure  => present,
  source  => '/usr/share/sensu/systemd/sensu-api.service',
  require => Package['sensu'],
}
service { 'sensu-api':
  ensure  => running,
  enable  => true,
  require => File['/usr/lib/systemd/system/sensu-api.service'],
}

file { '/etc/sensu/conf.d/client.json':
  ensure => present,
  content => '{
  "client": {
    "name": "monitor-host",
    "address": "127.0.0.1",
    "environment": "development",
    "subscriptions": [
      "dev",
      "rhel-hosts"
    ],
    "socket": {
      "bind": "127.0.0.1",
      "port": 3030
    }
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

package {'curl': ensure => present }
package {'jq': ensure => present }

# curl -s http://127.0.0.1:4567/clients | jq .


# Dashboard:
# https://uchiwa.io/#/
# https://uchiwa.io/#/download
# wget http://dl.bintray.com/palourde/uchiwa/uchiwa-0.25.3-1.x86_64.rpm
# md5sum ...
# rpm -ivh uchiwa-0.25.3-1.x86_64.rpm
# https://github.com/Yelp/puppet-uchiwa

#  https://www.godaddy.com/garage/tech/config/install-sensu-centos7/

# Source: https://github.com/Yelp/puppet-uchiwa/blob/master/manifests/service.pp
service { 'uchiwa':
      ensure     => running,
      enable     => true,
      hasstatus  => true,
      hasrestart => true,
}

file { '/etc/sensu/uchiwa.json':
    ensure  => file,
    content => '{
  "sensu": [
    {
      "name": "sensu",
      "host": "localhost",
      "port": 4567
    }
  ],
  "uchiwa": {
    "host": "0.0.0.0",
    "port": 3000,
    "refresh": 5
  }
}
',
    owner   => uchiwa,
    group   => uchiwa,
    mode    => '0440',
}


# TODO C Set-up checks: https://sensuapp.org/docs/1.0/quick-start/learn-sensu-basics.html
# https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/8/html/red_hat_openstack_platform_operational_tools/installing_the_availability_monitoring_suite
package {'nagios-plugins-http': ensure => present }
package {'nagios-plugins-ide_smart': ensure => present }

file { '/etc/sensu/conf.d/check_http.json':
  ensure => present,
  content => '{
  "checks": {
    "check_http": {
      "command": "/usr/lib64/nagios/plugins/check_http -I 127.0.0.1",
      "interval": 10,
      "subscribers": ["webserver"]
    }
  }
}',
}

file { '/etc/sensu/conf.d/check_http_repo_corp.json':
  ensure => present,
  content => '{
  "checks": {
    "check_http_artrepo_corp": {
      "command": "/usr/lib64/nagios/plugins/check_http -I 10.172.27.177 -u /artifacts",
      "interval": 10,
      "subscribers": ["http_artrepo_corp"]
    }
  }
}',
}


file { '/etc/sensu/conf.d/check_load.json':
  ensure => present,
  content => '{
  "checks": {
    "check_load": {
      "command": "/usr/lib64/nagios/plugins/check_load --percpu --warning=1,1,1 --critical=2,2,2",
      "interval": 300,
      "subscribers": ["rhel-hosts"]
    }
  }
}',
}


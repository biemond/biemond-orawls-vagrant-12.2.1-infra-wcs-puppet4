# jdk7::urandomfix
#
# On Linux low entropy can cause certain operations to be very slow.
# Encryption operations need entropy to ensure randomness. Entropy is
# generated by the OS when you use the keyboard, the mouse or the disk.
#
# If an encryption operation is missing entropy it will wait until
# enough is generated.
#
# three options
#  use rngd service (this class)
#  set java.security in JDK ( jre/lib/security )
#  set -Djava.security.egd=file:/dev/./urandom param
#
class jdk7::urandomfix () {

  $path = lookup('jdk7::exec_path')

  case $facts['operatingsystemmajrelease'] {
    5:       { $rng_package = 'rng-utils' }
    default: { $rng_package = 'rng-tools' }
  }

  if !defined(Package[$rng_package]) {
    package{$rng_package:
      ensure => present,
    }
  }

  case $facts['osfamily'] {
    'RedHat': {
      case $facts['operatingsystemmajrelease'] {
        '7': {
          exec { 'set urandom /lib/systemd/system/rngd.service':
            command => "sed -i -e's/ExecStart=\\/sbin\\/rngd -f/ExecStart=\\/sbin\\/rngd -r \\/dev\\/urandom -o \\/dev\\/random -f/g' /lib/systemd/system/rngd.service;systemctl daemon-reload;systemctl restart rngd.service",
            unless  => "/bin/grep 'ExecStart=/sbin/rngd -r /dev/urandom -o /dev/random -f' /lib/systemd/system/rngd.service",
            require => Package[$rng_package],
            user    => 'root',
            path    => $path,
          }

          exec { 'systemctl-daemon-reload':
            command     => 'systemctl --system daemon-reload',
            path        => $path,
            subscribe   => Exec['set urandom /lib/systemd/system/rngd.service'],
            refreshonly => true,
            notify      => Service['rngd'],
          }

          service { 'rngd':
            ensure  => 'running',
            enable  => true,
            require => Exec['systemctl-daemon-reload'],
          }
        }
        '6': {
          exec { 'set urandom /etc/sysconfig/rngd':
            command   => "sed -i -e's/EXTRAOPTIONS=\"\"/EXTRAOPTIONS=\"-r \\/dev\\/urandom -o \\/dev\\/random -b\"/g' /etc/sysconfig/rngd",
            unless    => "/bin/grep '^EXTRAOPTIONS=\"-r /dev/urandom -o /dev/random -b\"' /etc/sysconfig/rngd",
            require   => Package[$rng_package],
            path      => $path,
            logoutput => true,
            user      => 'root',
            notify    => Service['rngd'],
          }

          service { 'rngd':
            ensure  => 'running',
            enable  => true,
            require => Exec['set urandom /etc/sysconfig/rngd'],
          }

          exec { 'chkconfig rngd':
            command   => 'chkconfig --add rngd',
            require   => Service['rngd'],
            unless    => "chkconfig | /bin/grep 'rngd'",
            path      => $path,
            logoutput => true,
            user      => 'root',
          }
        }
        '5': {
          exec{'enable_entropy_daemon':
            command => '/sbin/rngd -r /dev/urandom -t 10',
            unless  => '/bin/ps -ef | grep urandom | grep -v grep',
            require => Package[$rng_package],
          }
        }
      }
    }
    'Debian': {
      exec { 'set urandom /etc/default/rng-tools':
        command   => "sed -i -e's/#HRNGDEVICE=\\/dev\\/null/HRNGDEVICE=\\/dev\\/urandom/g' /etc/default/rng-tools",
        unless    => "/bin/grep '^HRNGDEVICE=/dev/urandom' /etc/default/rng-tools",
        require   => Package['rng-tools'],
        path      => $path,
        logoutput => true,
        user      => 'root',
        notify    => Service['rng-tools'],
      }
      service { 'rng-tools':
        ensure  => 'running',
        enable  => true,
        require => Exec['set urandom /etc/default/rng-tools'],
      }
    }
    'Suse': {
      exec { 'set urandom /etc/default/rng-tools':
        command   => "sed -i -e's/#HRNGDEVICE=\\/dev\\/null/HRNGDEVICE=\\/dev\\/urandom/g' /etc/default/rng-tools",
        unless    => "/bin/grep '^HRNGDEVICE=/dev/urandom' /etc/default/rng-tools",
        require   => Package['rng-tools'],
        path      => $path,
        logoutput => true,
        user      => 'root',
        notify    => Service['rng-tools'],
        onlyif    => 'test -f /lib/systemd/system/rngd.service',
      }
      service { 'rng-tools':
        ensure  => 'running',
        enable  => true,
        require => Exec['set urandom /etc/default/rng-tools'],
      }
    }
    default: {
      fail("Unrecognized osfamily ${facts['osfamily']}, please use it on a Linux host")
    }
  }
}
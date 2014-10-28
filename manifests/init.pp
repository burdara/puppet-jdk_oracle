# == Class: jdk_oracle
#
# Installs the Oracle Java JDK, from the Oracle servers
#
# === Parameters
#
# [*version*]
#   String.  Java Version to install
#   Defaults to <tt>7</tt>.
#
# [* java_install_dir *]
#   String.  Java Installation Directory
#   Defaults to <tt>/opt</tt>.
#
# [* use_cache *]
#   String.  Optionally host the installer file locally instead of fetching it each time (for faster dev & test)
#   The puppet cache flag is for faster local vagrant development, to
#   locally host the tarball from oracle instead of fetching it each time.
#   Defaults to <tt>false</tt>.
#
# [* platform *]
#   String.  The platform to use
#   Defaults to <tt>x64</tt>.
#
#
define jdk_oracle(
    $version       = hiera('jdk_oracle::version',       '7' ),
    $install_dir   = hiera('jdk_oracle::install_dir',   '/opt' ),
    $use_cache     = hiera('jdk_oracle::use_cache',     false ),
    $platform      = hiera('jdk_oracle::platform',      'x64' ),
    $is_primary    = hiera('jdk_orable::is_primary', false),
) {

    # Set default exec path for this module
    Exec { path    => ['/usr/bin', '/usr/sbin', '/bin'] }

    case $platform {
        'x64': {
            $plat_filename = 'x64'
        }
        'x86': {
            $plat_filename = 'i586'
        }
        default: {
            fail("Unsupported platform: ${platform}.  Implement me?")
        }
    }

    case $version {
        '8': {
            $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/8-b132/jdk-8-linux-${plat_filename}.tar.gz"
            $java_home = "${install_dir}/jdk1.8.0"
        }
        '7': {
            $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-${plat_filename}.tar.gz"
            $java_home = "${install_dir}/jdk1.7.0"
        }
        '6': {
            $javaDownloadURI = "https://edelivery.oracle.com/otn-pub/java/jdk/6u45-b06/jdk-6u45-linux-${plat_filename}.bin"
            $java_home = "${install_dir}/jdk1.6.0_45"
        }
        default: {
            fail("Unsupported version: ${version}.  Implement me?")
        }
    }

    $installerFilename = inline_template('<%= File.basename(@javaDownloadURI) %>')

    if ( $use_cache ){
        notify { "Using local cache for oracle java ${version}": }
        file { "${install_dir}/${installerFilename}":
            source  => "puppet:///modules/jdk_oracle/${installerFilename}",
        }
        exec { "get_jdk_installer_${version}":
            cwd     => $install_dir,
            creates => "${install_dir}/jdk_from_cache",
            command => 'touch jdk_from_cache',
            require => File["${install_dir}/jdk-${version}-linux-x64.tar.gz"],
        }
    } else {
        exec { "get_jdk_installer_${version}":
            cwd     => $install_dir,
            creates => "${install_dir}/${installerFilename}",
            command => "wget -c --no-cookies --no-check-certificate --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com\" --header \"Cookie: oraclelicense=accept-securebackup-cookie\" \"${javaDownloadURI}\" -O ${installerFilename}",
            timeout => 600,
            require => Package['wget'],
        }
        file { "${install_dir}/${installerFilename}":
            mode    => '0755',
            require => Exec["get_jdk_installer_${version}"],
        }
    }

    # Java 7/8 comes in a tarball so just extract it.
    if ( $version in [ '7', '8' ] ) {
        exec { "extract_jdk_${version}":
            cwd     => "${install_dir}/",
            command => "tar -xf ${installerFilename}",
            creates => $java_home,
            require => Exec["get_jdk_installer_${version}"],
        }
    }
    # Java 6 comes as a self-extracting binary
    if ( $version == '6' ) {
        exec { "extract_jdk_${version}":
            cwd     => "${install_dir}/",
            command => "${install_dir}/${installerFilename}",
            creates => $java_home,
            require => File["${install_dir}/${installerFilename}"],
        }
    }

    # Set links depending on osfamily or operating system fact
    if ( $is_primary ) {
      file { "${install_dir}/java_home":
          ensure  => link,
          target  => $java_home,
          require => Exec["extract_jdk_${version}"],
      }
    }
    file { "${install_dir}/jdk-${version}":
        ensure  => link,
        target  => $java_home,
        require => Exec["extract_jdk_${version}"],
    }

    define setup_sbin_java($primary) {
      if ( $primary ) {
        file {
            '/usr/sbin/java':
                ensure  => link,
                target  => '/etc/alternatives/java';
            '/usr/sbin/javac':
                ensure  => link,
                target  => '/etc/alternatives/javac';
        }
      }
    }

    case $::osfamily {
        RedHat: {
            exec { ["/usr/sbin/alternatives --install /usr/bin/java java ${java_home}/bin/java 20000",
                    "/usr/sbin/alternatives --install /usr/bin/javac javac ${java_home}/bin/java 20000"]:
                require => Exec["extract_jdk_${version}"],
            } ->
            exec { ["/usr/sbin/alternatives --set java ${java_home}/bin/java",
                    "/usr/sbin/alternatives --set javac ${java_home}/bin/java"]:
            } ->
            setup_sbin_java { "sbin_${version}":
              primary => $is_primary
            }
        }
        Debian, Suse:    {
            exec { ["/usr/sbin/update-alternatives --install /usr/bin/java java ${java_home}/bin/java 20000",
                    "/usr/sbin/update-alternatives --install /usr/bin/javac javac ${java_home}/bin/javac 20000"]:
                require => Exec["extract_jdk_${version}"],
            } ->
            exec { ["/usr/sbin/update-alternatives --set java ${java_home}/bin/java",
                    "/usr/sbin/update-alternatives --set javac ${java_home}/bin/javac"]:
            } ->
            setup_sbin_java { "sbin_${version}":
              primary => $is_primary
            }
        }
        Solaris:   { fail('Not currently supported; please implement me!') }
        Gentoo:    { fail('Not currently supported; please implement me!') }
        Archlinux: { fail('Not currently supported; please implement me!') }
        Mandrake:  { fail('Not currently supported: please implement me!') }
        default:     { fail('Unsupported OS') }
    }
}

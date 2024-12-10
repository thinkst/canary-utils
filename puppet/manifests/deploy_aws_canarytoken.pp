node 'yahbuntu' {
  # Define necessary variables
  $console = '.canary.tools'
  $token = ''
  $flock = 'Default+Flock'
  $filepath = "/home/${facts['identity']['user']}"
  $filename = 'credentials.txt'
  $fullpath = "${filepath}/${filename}"

  # Create a temporary script to handle token creation and credential writing
  $script_path = "${filepath}/generate_aws_canarytoken.sh"

  # Ensure the directory exists
  file { $filepath:
    ensure => 'directory',
    owner  => $facts['identity']['user'],
    group  => $facts['identity']['group'],
    mode   => '0755',
  }

  # Create the script file
  file { $script_path:
    ensure  => 'file',
    owner   => $facts['identity']['user'],
    group   => $facts['identity']['group'],
    mode    => '0755',
    content => template('canarytoken/generate_aws_canarytoken.sh.erb'), # Template described below
    require => File[$filepath],
  }

  # Execute the script to create the Canarytoken and write credentials
  exec { 'deploy_aws_canarytoken':
    command => $script_path,
    path    => ['/bin', '/usr/bin', '/usr/local/bin'],
    unless  => "test -f ${fullpath}", # Only run if the credentials file doesn't exist
    require => File[$script_path],
  }
} 

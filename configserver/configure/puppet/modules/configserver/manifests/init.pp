class configserver {
  service { "configserver":
    name       => "aeolus-configserver",
    hasstatus  => true,
    hasrestart => true,
    ensure     => "running",
  }

  package { "configserver":
    name       => "aeolus-configserver",
    ensure     => installed,
  }
}

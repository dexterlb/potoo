use Mix.Config

config :potoo_server,
  root_target: :potoo_global_registry,
  dev_proxy: false,
  tcp_port: 4123,
  web_port: 4040

config :logger,
  backends: [:console],
  level: :warn,
  compile_time_purge_matching: [
    [level_lower_than: :warn]
  ]

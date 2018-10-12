use Mix.Config

config :server,
  root_target: :global_registry,
  dev_proxy: false,
  tcp_port: 4444,
  web_port: 4040

config :logger,
  backends: [:console],
  level: :warn,
  compile_time_purge_matching: [
    [level_lower_than: :warn]
  ]

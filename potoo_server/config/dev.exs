use Mix.Config

config :server,
  root_target: {:potoo_potoo_global_registry, :reg@localhost},
  dev_proxy: true,
  tcp_port: 4444,
  web_port: 4040

config :fidget,
  registry_node: :reg@localhost,
  registry: {:potoo_potoo_global_registry, :reg@localhost}

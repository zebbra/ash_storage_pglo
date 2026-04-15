import Config

config :ash_storage_pglo, AshStoragePGLO.Test.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ash_storage_pglo_test",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false

config :ash_storage_pglo,
  ecto_repos: [AshStoragePGLO.Test.Repo],
  ash_domains: [AshStoragePGLO.Test.Domain]

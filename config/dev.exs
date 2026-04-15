import Config

config :ash_storage_pglo, Demo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ash_storage_pglo_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :ash_storage_pglo,
  ecto_repos: [Demo.Repo]

config :ash_storage_pglo, :oban,
  repo: Demo.Repo,
  plugins: [{Oban.Plugins.Cron, []}],
  queues: [blob_purge_blob: 10, blob_run_pending_analyzers: 10]

[
  import_deps: [:ash_postgres, :ash, :ash_storage, :reactor, :ecto, :ecto_sql],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]

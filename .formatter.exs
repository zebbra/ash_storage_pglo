[
  import_deps: [:ash_postgres, :ash, :ash_storage, :reactor, :ecto, :ecto_sql],
  locals_without_parens: [bufsize: 1],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]

defmodule AshStoragePGLO.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_storage_pglo,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, ash_version("~> 3.5")},
      {:ash_postgres, "~> 2.0"},
      {:ash_oban, "~> 0.7", optional: true},
      {:ash_storage, github: "StephanH90/ash_storage", branch: "fix/set-relationship-source"},
      {:pg_large_objects, "~> 0.2"},
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      # dev/test dependencies
      {:phoenix, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.0", only: :dev},
      {:ash_phoenix, "~> 2.0", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.37-rc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:simple_sat, ">= 0.0.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      dev: "run --no-halt dev.exs --config config",
      "dev.setup": ["deps.get", "ash_postgres.create", "dev.migrate"],
      "dev.migrate": "ash_postgres.migrate --migrations-path dev/repo/migrations",
      "dev.generate_migrations":
        "ash_postgres.generate_migrations --domains Demo.Domain --snapshot-path dev/resource_snapshots --migration-path dev/repo/migrations",
      "dev.reset": ["ash_postgres.drop", "ash_postgres.create", "dev.migrate"],
      "test.migrate": "ash_postgres.migrate --migrations-path priv/test_repo/migrations",
      "test.generate_migrations":
        "ash_postgres.generate_migrations --domains AshStoragePGLO.Test.Domain --snapshot-path priv/resource_snapshots/test_repo --migration-path priv/test_repo/migrations",
      docs: [
        "docs",
        "spark.replace_doc_links"
      ]
    ]
  end
end

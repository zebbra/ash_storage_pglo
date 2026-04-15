defmodule Demo.Repo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_storage_pglo

  def installed_extensions do
    ["uuid-ossp", "ash-functions", "lo"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end

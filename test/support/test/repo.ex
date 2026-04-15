defmodule AshStoragePGLO.Test.Repo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_storage_pglo

  def installed_extensions do
    ["ash-functions", "lo"]
  end

  def prefer_transaction?, do: false
  def prefer_transaction_for_atomic_updates?, do: false

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end

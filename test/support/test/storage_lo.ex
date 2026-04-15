defmodule AshStoragePGLO.Test.StorageLO do
  @moduledoc false
  use Ash.Resource,
    domain: AshStoragePGLO.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStoragePGLO.Resource]

  postgres do
    table "storage_los"
    repo AshStoragePGLO.Test.Repo
  end

  lo do
  end
end

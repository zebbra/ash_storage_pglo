defmodule AshStoragePGLO.Test.StorageLOLargeBufsize do
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
    bufsize 4_194_304
  end
end

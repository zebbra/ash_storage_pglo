defmodule AshStoragePGLO.Test.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshStoragePGLO.Test.StorageLO
    resource AshStoragePGLO.Test.StorageLOLargeBufsize
  end
end

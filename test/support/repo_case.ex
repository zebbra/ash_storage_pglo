defmodule AshStoragePGLO.RepoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias AshStoragePGLO.Test.Repo
    end
  end

  setup tags do
    :ok = Sandbox.checkout(AshStoragePGLO.Test.Repo)

    if !tags[:async] do
      Sandbox.mode(AshStoragePGLO.Test.Repo, {:shared, self()})
    end

    :ok
  end
end

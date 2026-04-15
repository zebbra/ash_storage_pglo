{:ok, _} = Application.ensure_all_started(:ash_storage_pglo)
{:ok, _} = AshStoragePGLO.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(AshStoragePGLO.Test.Repo, :manual)
ExUnit.start()

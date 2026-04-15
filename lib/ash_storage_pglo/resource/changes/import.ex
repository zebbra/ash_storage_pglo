defmodule AshStoragePGLO.Resource.Changes.Import do
  @moduledoc """
  Change for the `:import` create action on `AshStoragePGLO.Resource` resources.

  Runs inside the action's transaction. Imports the `:data` argument into a
  new PostgreSQL large object via `PgLargeObjects.import/3` and force-changes
  `:oid` on the changeset.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      data = Ash.Changeset.get_argument(changeset, :data)
      repo = AshPostgres.DataLayer.Info.repo(changeset.resource)

      case PgLargeObjects.import(repo, data) do
        {:ok, oid} ->
          Ash.Changeset.force_change_attribute(changeset, :oid, oid)

        {:error, error} ->
          Ash.Changeset.add_error(changeset, error)
      end
    end)
  end
end

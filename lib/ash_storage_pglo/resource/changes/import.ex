defmodule AshStoragePGLO.Resource.Changes.Import do
  @moduledoc """
  Change for the `:import` create action on `AshStoragePGLO.Resource` resources.

  Runs inside the action's transaction. Imports the `:data` argument into a
  new PostgreSQL large object via `PgLargeObjects.import/3` and force-changes
  `:oid` on the changeset.
  """

  use Ash.Resource.Change

  alias AshPostgres.DataLayer.Info

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      resource = changeset.resource
      data = Ash.Changeset.get_argument(changeset, :data)
      repo = Info.repo(resource)
      bufsize = AshStoragePGLO.Resource.Info.bufsize(resource)

      {:ok, oid} = PgLargeObjects.import(repo, data, bufsize: bufsize)
      Ash.Changeset.force_change_attribute(changeset, :oid, oid)
    end)
  end
end

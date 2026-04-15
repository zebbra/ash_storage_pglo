defmodule AshStoragePGLO.ServicePostgresTest do
  use AshStoragePGLO.RepoCase, async: false

  alias AshStoragePGLO.Service
  alias AshStoragePGLO.Test.StorageLO
  alias AshStorage.Service.Context

  @service_opts [resource: StorageLO, base_url: "/storage"]

  defp ctx, do: Context.new(@service_opts)

  test "upload then download round-trips a binary" do
    assert :ok = Service.upload("hello.txt", "hello world", ctx())
    assert {:ok, "hello world"} = Service.download("hello.txt", ctx())
  end

  test "upload from an enumerable streams chunks into a large object" do
    chunks = ["lorem ", "ipsum ", "dolor"]
    assert :ok = Service.upload("stream.txt", chunks, ctx())
    assert {:ok, "lorem ipsum dolor"} = Service.download("stream.txt", ctx())
  end

  test "exists?/2 returns true after upload and false before" do
    assert {:ok, false} = Service.exists?("nope.txt", ctx())
    assert :ok = Service.upload("yep.txt", "yep", ctx())
    assert {:ok, true} = Service.exists?("yep.txt", ctx())
  end

  test "download returns :not_found for missing key" do
    assert {:error, :not_found} = Service.download("missing.txt", ctx())
  end

  test "delete removes the mapping row AND the underlying large object" do
    require Ash.Query

    assert :ok = Service.upload("gone.txt", "bytes", ctx())

    %StorageLO{oid: oid} = Ash.get!(StorageLO, "gone.txt")

    assert :ok = Service.delete("gone.txt", ctx())

    assert {:error, :not_found} = Service.download("gone.txt", ctx())

    %{num_rows: 0} =
      AshStoragePGLO.Test.Repo.query!(
        "SELECT 1 FROM pg_largeobject_metadata WHERE oid = $1",
        [oid]
      )
  end

  test "delete on a missing key is a no-op" do
    assert :ok = Service.delete("already-gone.txt", ctx())
  end
end

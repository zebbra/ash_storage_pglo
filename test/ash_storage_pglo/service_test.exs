defmodule AshStoragePGLO.ServicePostgresTest do
  use AshStoragePGLO.RepoCase, async: true

  alias AshStorage.Service.Context
  alias AshStoragePGLO.Service
  alias AshStoragePGLO.Test.{Repo, StorageLO}

  @service_opts [lo_resource: StorageLO, base_url: "/storage"]

  defp ctx, do: Context.new(@service_opts)

  test "implements AshStorage.Service behaviour" do
    behaviours =
      :attributes
      |> Service.module_info()
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert AshStorage.Service in behaviours
  end

  test "service_opts_fields exposes lo_resource and base_url" do
    fields = Service.service_opts_fields()
    assert Keyword.has_key?(fields, :lo_resource)
    assert Keyword.has_key?(fields, :base_url)
  end

  describe "url/2" do
    test "joins base_url and key" do
      ctx = Context.new(base_url: "/storage")
      assert Service.url("abc/def.jpg", ctx) == "/storage/abc/def.jpg"
    end

    test "raises if base_url is missing" do
      ctx = Context.new([])
      assert_raise KeyError, fn -> Service.url("abc", ctx) end
    end
  end

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
      Repo.query!(
        "SELECT 1 FROM pg_largeobject_metadata WHERE oid = $1",
        [oid]
      )
  end

  test "delete on a missing key is a no-op" do
    assert :ok = Service.delete("already-gone.txt", ctx())
  end
end

defmodule AshStoragePGLO.ServiceTest do
  use ExUnit.Case, async: false

  alias AshStoragePGLO.Service

  test "implements AshStorage.Service behaviour" do
    behaviours =
      :attributes
      |> Service.module_info()
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert AshStorage.Service in behaviours
  end

  test "service_opts_fields exposes resource and base_url" do
    fields = Service.service_opts_fields()
    assert Keyword.has_key?(fields, :resource)
    assert Keyword.has_key?(fields, :base_url)
  end

  describe "url/2" do
    test "joins base_url and key" do
      ctx = AshStorage.Service.Context.new(base_url: "/storage")
      assert Service.url("abc/def.jpg", ctx) == "/storage/abc/def.jpg"
    end

    test "raises if base_url is missing" do
      ctx = AshStorage.Service.Context.new([])
      assert_raise KeyError, fn -> Service.url("abc", ctx) end
    end
  end
end

defmodule Demo.Page do
  @moduledoc false
  use Ash.Resource,
    domain: Demo.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage]

  postgres do
    table "pages"
    repo(Demo.Repo)
  end

  storage do
    service(
      {AshStorage.Service.Disk,
       root: "tmp/dev_storage",
       base_url: "/disk_files",
       secret: "dev-secret-key-for-signed-urls!!"}
    )

    blob_resource(Demo.Blob)
    attachment_resource(Demo.Attachment)

    has_one_attached :cover_image do
      analyzer Demo.Analyzers.FileInfo

      analyzer Demo.Analyzers.ImageDimensions,
        analyze: :oban,
        write_attributes: [width: :image_width, height: :image_height]
    end

    has_many_attached :documents do
      analyzer Demo.Analyzers.FileInfo

      variant :uppercase, Demo.Variants.Uppercase, generate: :eager
      variant :reversed, Demo.Variants.Reversed, generate: :oban
      variant :excerpt, {Demo.Variants.Excerpt, max_chars: 50}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :image_width, :integer, public?: true
    attribute :image_height, :integer, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:title], update: [:title]]
  end
end

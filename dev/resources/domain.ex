defmodule Demo.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Demo.Post
    resource Demo.Page
    resource Demo.Blob
    resource Demo.Attachment
  end
end

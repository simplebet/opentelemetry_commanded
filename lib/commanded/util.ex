defmodule OpentelemetryCommanded.Util do
  @moduledoc false

  def encode_ctx(:undefined), do: :undefined
  def encode_ctx(ctx), do: Tuple.to_list(ctx)

  def decode_ctx("undefined"), do: :undefined

  def decode_ctx(ctx) do
    Enum.map(ctx, fn
      el when is_binary(el) -> String.to_existing_atom(el)
      el -> el
    end)
    |> List.to_tuple()
  end

  def struct_name(%name{}) do
    name
  end

end

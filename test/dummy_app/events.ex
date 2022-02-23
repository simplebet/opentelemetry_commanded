defmodule OpentelemetryCommanded.DummyApp.Events do
  @moduledoc false

  defmodule OkEvent do
    @derive Jason.Encoder
    defstruct [:id]
  end

  defmodule ErrorInEventHandlerEvent do
    @derive Jason.Encoder
    defstruct [:id, :message]
  end

  defmodule ExceptionInEventHandlerEvent do
    @derive Jason.Encoder
    defstruct [:id, :message]
  end
end

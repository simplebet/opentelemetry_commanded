defmodule OpentelemetryCommanded.DummyApp.Handler do
  @behaviour Commanded.Commands.Handler

  alias OpentelemetryCommanded.DummyApp.Aggregate
  alias OpentelemetryCommanded.DummyApp.Commands, as: C
  alias OpentelemetryCommanded.DummyApp.Events, as: E

  def handle(%Aggregate{}, %C.Ok{}), do: %E.OkEvent{}
  def handle(%Aggregate{}, %C.Error{message: message}), do: {:error, message}
  def handle(%Aggregate{}, %C.RaiseException{message: "some error"}), do: raise("some error")
  def handle(%Aggregate{}, %C.DoEvent{event: event}), do: event
end

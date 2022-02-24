defmodule OpentelemetryCommanded.EventStoreTest do
  use OpentelemetryCommanded.CommandedCase, async: false

  import ExUnit.CaptureLog

  alias OpentelemetryCommanded.DummyApp.Commands, as: C
  alias OpentelemetryCommanded.DummyApp.Events, as: E

  describe "dispatch command when Telemetry attached" do
    setup _ do
      case OpentelemetryCommanded.EventStore.setup() do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end
    end

    test "Success should create span", context do
      :ok = app_dispatch(context, %C.Ok{id: "ACC123"})

      assert_receive {:span,
                      span(
                        name: "commanded.event_store.ack_event",
                        kind: :consumer,
                        attributes: attributes
                      )}

      attributes = :otel_attributes.map(attributes)

      has_basic_attributes!(attributes, context.correlation_id)

      assert match?(
               %{
                 "messaging.commanded.event":
                   "Elixir.OpentelemetryCommanded.DummyApp.Events.OkEvent"
               },
               attributes
             )
    end
  end

  defp has_basic_attributes!(attributes, correlation_id) do
    assert match?(
             %{
               "messaging.commanded.application": OpentelemetryCommanded.DummyApp.App,
               "messaging.commanded.event_id": _,
               "messaging.commanded.event_number": 1,
               "messaging.commanded.stream_id": "ACC123",
               "messaging.commanded.stream_version": 1,
               "messaging.conversation_id": ^correlation_id,
               "messaging.destination_kind": "event_store",
               "messaging.message_id": _,
               "messaging.operation": "receive",
               "messaging.protocol": "cqrs",
               "messaging.system": "commanded",
               "messaging.commanded.event": _
             },
             attributes
           )
  end
end

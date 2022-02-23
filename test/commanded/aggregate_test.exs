defmodule OpentelemetryCommanded.AggregateTest do
  use OpentelemetryCommanded.CommandedCase, async: false

  import ExUnit.CaptureLog

  alias OpentelemetryCommanded.DummyApp.Commands, as: C

  describe "dispatch command when Telemetry attached" do
    setup _ do
      case OpentelemetryCommanded.Aggregate.setup() do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end
    end

    test "Success should create span", context do
      :ok = app_dispatch(context, %C.Ok{id: "ACC123"})

      assert_receive {:span,
                      span(
                        name: "commanded.aggregate.execute",
                        kind: :consumer,
                        attributes: attributes
                      )}

      refute_receive {:span,
                      span(
                        name: "commanded.aggregate.execute",
                        status: _
                      )}

      attributes = :otel_attributes.map(attributes)

      has_basic_attributes!(attributes, context.correlation_id)

      assert match?(
               %{
                 "messaging.commanded.command": OpentelemetryCommanded.DummyApp.Commands.Ok
               },
               attributes
             )
    end

    test "Error should create span with error set", context do
      _log =
        capture_log(fn ->
          # TODO: shouldn't be same command as for application_test
          {:error, "some error"} =
            app_dispatch(context, %C.Error{id: "ACC123", message: "some error"})
        end)

      assert_receive {:span,
                      span(
                        name: "commanded.aggregate.execute",
                        kind: :consumer,
                        status: {:status, :error, exception_message},
                        attributes: attributes
                      )}

      attributes = :otel_attributes.map(attributes)

      has_basic_attributes!(attributes, context.correlation_id)

      assert match?(
               %{
                 "messaging.commanded.command": OpentelemetryCommanded.DummyApp.Commands.Error
               },
               attributes
             )

      assert exception_message =~ "some error"
    end

    test "Exception should create span with error set", context do
      _log =
        capture_log(fn ->
          {:error, %RuntimeError{message: "some error"}} =
            app_dispatch(context, %C.RaiseException{id: "ACC123", message: "some error"})
        end)

      assert_receive {:span,
                      span(
                        name: "commanded.aggregate.execute",
                        kind: :consumer,
                        status: {:status, :error, exception_message},
                        attributes: attributes,
                        events: events
                      )}

      attributes = :otel_attributes.map(attributes)

      has_basic_attributes!(attributes, context.correlation_id)

      assert match?(
               %{
                 "messaging.commanded.command":
                   OpentelemetryCommanded.DummyApp.Commands.RaiseException
               },
               attributes
             )

      assert exception_message =~ "some error"

      [
        event(
          name: "exception",
          attributes: event_attributes
        )
      ] = :otel_events.list(events)

      event_attributes = :otel_attributes.map(event_attributes)

      assert match?(
               %{
                 "exception.message" => "some error",
                 "exception.stacktrace" => _,
                 "exception.type" => "Elixir.RuntimeError"
               },
               event_attributes
             )

      stack_trace = event_attributes["exception.stacktrace"]
      assert stack_trace =~ "OpentelemetryCommanded.DummyApp.Handler.handle/2"
    end
  end

  defp has_basic_attributes!(attributes, correlation_id) do
    assert match?(
             %{
               "messaging.commanded.aggregate_uuid": "ACC123",
               "messaging.commanded.aggregate_version": 0,
               "messaging.commanded.application": OpentelemetryCommanded.DummyApp.App,
               "messaging.commanded.command": _,
               "messaging.commanded.function": :handle,
               "messaging.conversation_id": ^correlation_id,
               "messaging.destination": OpentelemetryCommanded.DummyApp.Handler,
               "messaging.destination_kind": "aggregate",
               "messaging.message_id": _,
               "messaging.operation": "receive",
               "messaging.protocol": "cqrs",
               "messaging.system": "commanded"
             },
             attributes
           )
  end
end
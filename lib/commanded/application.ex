defmodule OpentelemetryCommanded.Application do
  @moduledoc false

  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  def setup do
    :telemetry.attach(
      {__MODULE__, :start},
      [:commanded, :application, :dispatch, :start],
      &__MODULE__.handle_start/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :stop},
      [:commanded, :application, :dispatch, :stop],
      &__MODULE__.handle_stop/4,
      []
    )
  end

  def handle_start(_event, _, meta, _) do
    context = meta.execution_context

    attributes = [
      "messaging.system": "commanded",
      "messaging.protocol": "cqrs",
      "messaging.destination_kind": "command_handler",
      "messaging.operation": "receive",
      "messaging.destination": context.handler,
      "messaging.message_id": context.causation_id,
      "messaging.conversation_id": context.correlation_id,
      "messaging.commanded.application": meta.application,
      "messaging.commanded.command": struct_name(context.command),
      "messaging.commanded.function": context.function
    ]

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "commanded.application.dispatch",
      meta,
      %{
        kind: :consumer,
        attributes: attributes
      }
    )
  end

  def handle_stop(_event, _measurements, meta, _) do
    # ensure the correct span is current and update the status
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    if error = meta[:error] do
      Span.set_status(ctx, OpenTelemetry.status(:error, inspect(error)))
    end

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end
end

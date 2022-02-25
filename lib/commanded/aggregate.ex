defmodule OpentelemetryCommanded.Aggregate do
  @moduledoc false

  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  def setup() do
    :telemetry.attach(
      {__MODULE__, :start},
      [:commanded, :aggregate, :execute, :start],
      &__MODULE__.handle_start/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :stop},
      [:commanded, :aggregate, :execute, :stop],
      &__MODULE__.handle_stop/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :exception},
      [:commanded, :aggregate, :execute, :exception],
      &__MODULE__.handle_exception/4,
      []
    )
  end

  def handle_start(_event, _, meta, _) do
    context = meta.execution_context

    safe_context_propagation(context.metadata["trace_ctx"])

    attributes = [
      "messaging.system": "commanded",
      "messaging.protocol": "cqrs",
      "messaging.destination_kind": "aggregate",
      "messaging.operation": "receive",
      "messaging.destination": context.handler,
      "messaging.message_id": context.causation_id,
      "messaging.conversation_id": context.correlation_id,
      "messaging.commanded.aggregate_uuid": meta.aggregate_uuid,
      "messaging.commanded.aggregate_version": meta.aggregate_version,
      "messaging.commanded.application": meta.application,
      "messaging.commanded.command": struct_name(context.command),
      "messaging.commanded.function": context.function
    ]

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "commanded.aggregate.execute",
      meta,
      %{
        kind: :consumer,
        attributes: attributes
      }
    )
  end

  def handle_stop(_event, _measurements, meta, _) do
    # ensure the correct span is current
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    events = Map.get(meta, :events, [])
    Span.set_attribute(ctx, :"messaging.commanded.event_count", Enum.count(events))

    if error = meta[:error] do
      Span.set_status(ctx, OpenTelemetry.status(:error, inspect(error)))
    end

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end

  def handle_exception(
        _event,
        _measurements,
        %{kind: kind, reason: reason, stacktrace: stacktrace} = meta,
        _config
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    # try to normalize all errors to Elixir exceptions
    exception = Exception.normalize(kind, reason, stacktrace)

    # record exception and mark the span as errored
    Span.record_exception(ctx, exception, stacktrace)
    Span.set_status(ctx, OpenTelemetry.status(:error, inspect(reason)))

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end
end

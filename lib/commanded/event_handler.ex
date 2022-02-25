defmodule OpentelemetryCommanded.EventHandler do
  @moduledoc false

  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  def setup do
    :telemetry.attach(
      {__MODULE__, :start},
      [:commanded, :event, :handle, :start],
      &__MODULE__.handle_start/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :stop},
      [:commanded, :event, :handle, :stop],
      &__MODULE__.handle_stop/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :exception},
      [:commanded, :event, :handle, :exception],
      &__MODULE__.handle_exception/4,
      []
    )
  end

  def handle_start(_event, _measurements, meta, _) do
    recorded_event = meta.recorded_event

    safe_context_propagation(recorded_event.metadata["trace_ctx"])

    attributes = [
      "messaging.system": "commanded",
      "messaging.protocol": "cqrs",
      "messaging.destination_kind": "event_handler",
      "messaging.operation": "receive",
      "messaging.message_id": recorded_event.causation_id,
      "messaging.conversation_id": recorded_event.correlation_id,
      "messaging.destination": meta.handler_module,
      "messaging.commanded.application": meta.application,
      "messaging.commanded.event": recorded_event.event_type,
      "messaging.commanded.event_id": recorded_event.event_id,
      "messaging.commanded.event_number": recorded_event.event_number,
      "messaging.commanded.stream_id": recorded_event.stream_id,
      "messaging.commanded.stream_version": recorded_event.stream_version,
      "messaging.commanded.handler_name": meta.handler_name
      # TODO add back
      # consistency: meta.consistency,
      #  TODO add this back into commanded
      # "event.last_seen": meta.last_seen_event
    ]

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "commanded.event.handle",
      meta,
      %{
        kind: :consumer,
        attributes: attributes
      }
    )
  end

  def handle_stop(_event, _measurements, meta, _) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

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

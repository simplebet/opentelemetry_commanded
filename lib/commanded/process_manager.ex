defmodule OpentelemetryCommanded.ProcessManager do
  @moduledoc false

  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  def setup do
    :telemetry.attach(
      {__MODULE__, :start},
      [:commanded, :process_manager, :handle, :start],
      &__MODULE__.handle_start/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :stop},
      [:commanded, :process_manager, :handle, :stop],
      &__MODULE__.handle_stop/4,
      []
    )

    :telemetry.attach(
      {__MODULE__, :exception},
      [:commanded, :process_manager, :handle, :exception],
      &__MODULE__.handle_exception/4,
      []
    )
  end

  def handle_start(_event, _, meta, _) do
    event = meta.recorded_event
    trace_headers = decode_headers(event.metadata["trace_ctx"])
    :otel_propagator_text_map.extract(trace_headers)

    attributes = [
      "messaging.system": "commanded",
      "messaging.protocol": "cqrs",
      "messaging.destination_kind": "process_manager",
      "messaging.operation": "receive",
      "messaging.message_id": event.causation_id,
      "messaging.conversation_id": event.correlation_id,
      "messaging.destination": meta.process_manager_module,
      "messaging.commanded.application": meta.application,
      "messaging.commanded.event": event.event_type,
      "messaging.commanded.event_id": event.event_id,
      "messaging.commanded.event_number": event.event_number,
      "messaging.commanded.process_uuid": meta.process_uuid,
      "messaging.commanded.stream_id": event.stream_id,
      "messaging.commanded.stream_version": event.stream_version,
      "messaging.commanded.handler_name": meta.process_manager_name
      # TODO add back
      # consistency: meta.consistency,
      #  TODO add this back into commanded
      # "event.last_seen": meta.last_seen_event
    ]

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "commanded.process_manager.handle",
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

    commands = Map.get(meta, :commands, [])
    Span.set_attribute(ctx, :"messaging.commanded.command_count", Enum.count(commands))

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

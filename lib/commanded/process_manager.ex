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
      application: meta.application,
      "process_manager.uuid": meta.process_uuid,
      "process_manager.name": meta.process_manager_name,
      "process_manager.module": meta.process_manager_module,
      "event.id": event.event_id,
      "event.number": event.event_number,
      "event.type": event.event_type,
      "correlation.id": event.correlation_id,
      "causation.id": event.causation_id,
      "stream.id": event.stream_id,
      "stream.version": event.stream_version
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
    Span.set_attribute(ctx, :"command.count", Enum.count(commands))

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
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end
end

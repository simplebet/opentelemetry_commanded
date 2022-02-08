defmodule OpentelemetryCommanded.EventHandler do
  @moduledoc false

  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.{Tracer, Span}

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
    event = meta.recorded_event
    trace_headers = decode_headers(event.metadata["trace_ctx"])
    :otel_propagator_text_map.extract(trace_headers)

    attributes = [
      "causation.id": event.causation_id,
      "correlation.id": event.correlation_id,
      "event.id": event.event_id,
      "event.number": event.event_number,
      "event.type": event.event_type,
      "stream.id": event.stream_id,
      "stream.version": event.stream_version,
      application: meta.application,
      # TODO add back
      # consistency: meta.consistency,
      "handler.module": meta.handler_module,
      "handler.name": meta.handler_name
      #  TODO add this back into commanded
      # "event.last_seen": meta.last_seen_event
    ]

    Tracer.start_span("commanded:event:handle", %{
      kind: :consumer,
      attributes: attributes
    })
  end

  def handle_stop(_event, _measurements, _meta, _) do
    Tracer.end_span()
  end

  def handle_exception(_event, _, %{kind: kind, reason: reason, stacktrace: stacktrace}, _) do
    ctx = Tracer.current_span_ctx()

    exception = Exception.normalize(kind, reason, stacktrace)
    Span.record_exception(ctx, exception, stacktrace)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    Tracer.end_span()
  end
end

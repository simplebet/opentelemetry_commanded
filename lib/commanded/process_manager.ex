defmodule OpentelemetryCommanded.ProcessManager do
  @moduledoc false

  require OpenTelemetry.Span
  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer

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

    Tracer.start_span("commanded:process_manager:handle", %{
      kind: :CONSUMER,
      parent: decode_ctx(event.metadata["trace_ctx"]),
      attributes: attributes
    })
  end

  def handle_stop(_event, _measurements, meta, _) do
    commands = Map.get(meta, :commands, [])
    Span.set_attribute(:"command.count", Enum.count(commands))
    Tracer.end_span()
  end

  def handle_exception(_event, _measurements, meta, _) do
    Span.set_attributes(error: true, "error.exception": inspect(meta.error))
    Tracer.end_span()
  end
end

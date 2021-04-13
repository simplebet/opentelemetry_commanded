defmodule OpentelemetryCommanded.Aggregate do
  @moduledoc false

  require OpenTelemetry.Span
  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer

  def setup do
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

    attributes = [
      "command.type": struct_name(context.command),
      "command.handler": context.handler,
      "aggregate.uuid": meta.aggregate_uuid,
      "aggregate.version": meta.aggregate_version,
      application: meta.application,
      "causation.id": context.causation_id,
      "correlation.id": context.correlation_id,
      "aggregate.function": context.function,
      "aggregate.lifespan": context.lifespan
    ]

    Tracer.start_span("commanded:aggregate:execute", %{
      kind: :CONSUMER,
      parent: decode_ctx(context.metadata.trace_ctx),
      attributes: attributes
    })
  end

  def handle_stop(_event, _measurements, meta, _) do
    events = Map.get(meta, :events, [])
    Span.set_attribute(:"event.count", Enum.count(events))
    Tracer.end_span()
  end

  def handle_exception(_event, _measurements, meta, _) do
    Span.set_attributes(error: true, "error.exception": inspect(meta[:error]))
    Tracer.end_span()
  end
end

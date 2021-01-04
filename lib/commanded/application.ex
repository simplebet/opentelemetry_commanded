defmodule OpentelemetryCommanded.Application do
  @moduledoc false

  require OpenTelemetry.Span
  require OpenTelemetry.Tracer

  import OpentelemetryCommanded.Util

  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer

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
      "command.type": struct_name(context.command),
      "command.handler": context.handler,
      application: meta.application,
      "causation.id": context.causation_id,
      "correlation.id": context.correlation_id,
      "aggregate.function": context.function,
      "aggregate.lifespan": context.lifespan
    ]

    Tracer.start_span("commanded:application:dispatch", %{
      kind: :CONSUMER,
      # parent: decode_ctx(context.metadata.trace_ctx),
      attributes: attributes
    })
  end

  def handle_stop(_event, _measurements, meta, _) do
    if error = meta[:error] do
      Span.set_attribute(:error, error)
    end

    Tracer.end_span()
  end
end

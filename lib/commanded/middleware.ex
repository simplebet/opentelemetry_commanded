defmodule OpentelemetryCommanded.Middleware do
  @moduledoc """
  A middleware for propagating span context to Aggregates, Event Handlers, etc

  Usage:

  ```elixir
  # In your commanded router

  middleware OpentelemetryCommanded.Middleware
  ```
  """

  @behaviour Commanded.Middleware

  require OpenTelemetry.Tracer

  import Commanded.Middleware.Pipeline

  alias Commanded.Middleware.Pipeline
  alias OpenTelemetry.Tracer

  def before_dispatch(%Pipeline{} = pipeline) do
    trace_ctx = Tracer.current_span_ctx()

    assign_metadata(pipeline, :trace_ctx, trace_ctx)
  end

  def after_dispatch(pipeline) do
    pipeline
  end

  def after_failure(pipeline) do
    pipeline
  end
end

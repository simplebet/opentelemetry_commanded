defmodule OpentelemetryCommanded.Middleware do
  @behaviour Commanded.Middleware

  require OpenTelemetry.Tracer

  import Commanded.Middleware.Pipeline
  import OpentelemetryCommanded.Util

  alias Commanded.Middleware.Pipeline
  alias OpenTelemetry.Tracer

  def before_dispatch(%Pipeline{command: command} = pipeline) do
    trace_ctx = Tracer.current_span_ctx()

    assign_metadata(pipeline, :trace_ctx, encode_ctx(trace_ctx))
  end

  def after_dispatch(pipeline) do
    pipeline
  end

  def after_failure(pipeline) do
    pipeline
  end
end

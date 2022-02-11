defmodule OpentelemetryCommanded.EventStore do
  @moduledoc false

  require OpenTelemetry.Tracer

  alias OpenTelemetry.{Tracer, Span}

  def setup do
    :telemetry.attach_many(
      {__MODULE__, :stop},
      [
        [:commanded, :event_store, :stream_forward, :stop],
        [:commanded, :event_store, :append_to_stream, :stop]
      ],
      &__MODULE__.handle_stop/4,
      []
    )

    :telemetry.attach_many(
      {__MODULE__, :exception},
      [
        [:commanded, :event_store, :stream_forward, :exception],
        [:commanded, :event_store, :append_to_stream, :exception]
      ],
      &__MODULE__.handle_stop/4,
      []
    )
  end

  def handle_stop([_, _, action, type], measurements, meta, _) do
    end_time = :opentelemetry.timestamp()
    start_time = end_time - measurements.duration
    attributes = meta |> Map.take([:application, :stream_uuid]) |> Enum.to_list()
    span_name = :"commanded:event_store:#{action}"

    Tracer.start_span(span_name, %{start_time: start_time, attributes: attributes})

    if type == :exception do
      ctx = Tracer.current_span_ctx()
      reason = meta[:reason]
      stacktrace = meta[:stacktrace]

      exception = Exception.normalize(meta[:kind], reason, stacktrace)
      Span.record_exception(ctx, exception, stacktrace)
      Span.set_status(ctx, OpenTelemetry.status(:error, ""))
    end

    Tracer.end_span()
  end
end

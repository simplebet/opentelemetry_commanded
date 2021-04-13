defmodule OpentelemetryCommanded.EventStore do
  @moduledoc false

  require OpenTelemetry.Tracer


  alias OpenTelemetry.Tracer

  # :stream_forward
  # :append_to_stream

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

    attributes =
      if type == :exception do
        attributes |> Keyword.put(:error, true)
      else
        attributes
      end

    span_name = :"commanded:event_store:#{action}"

    Tracer.start_span(span_name, %{start_time: start_time, attributes: attributes})

    Tracer.end_span()
  end
end

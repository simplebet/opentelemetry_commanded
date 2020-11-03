defmodule OpentelemetryCommanded do
  @moduledoc File.read!("./README.md")

  def setup do
    _ = OpenTelemetry.register_application_tracer(:commanded)

    OpentelemetryCommanded.Aggregate.setup()
    OpentelemetryCommanded.EventHandler.setup()
  end
end

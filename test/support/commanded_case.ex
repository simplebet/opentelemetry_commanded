defmodule OpentelemetryCommanded.CommandedCase do
  @moduledoc """
  A case template for tests relying on the CommandedApp
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import OpentelemetryCommanded.CommandedCase
    end
  end

  alias Commanded.Helpers.CommandAuditMiddleware
  alias OpentelemetryCommanded.DummyApp.App

  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    start_supervised!(CommandAuditMiddleware)
    start_supervised!(App)
    {:ok, _handler} = OpentelemetryCommanded.DummyApp.EventHandler.start_link()
    {:ok, _pid} = OpentelemetryCommanded.DummyApp.ProcessManager.start_link(start_from: :current)

    :application.stop(:opentelemetry)
    :application.set_env(:opentelemetry, :tracer, :otel_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    %{correlation_id: "b802ced4-02de-4f12-943e-42cef58658ed"}
  end

  def app_dispatch(context, command) do
    App.dispatch(command,
      application: OpentelemetryCommanded.DummyApp.App,
      correlation_id: context.correlation_id,
      consistency: :strong
    )
  end
end

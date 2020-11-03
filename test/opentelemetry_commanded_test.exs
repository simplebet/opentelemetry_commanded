defmodule OpentelemetryCommandedTest do
  use ExUnit.Case
  doctest OpentelemetryCommanded

  test "sets it up!" do
    assert OpentelemetryCommanded.setup() == :ok
  end
end

defmodule School.Player do
  @type t :: %__MODULE__{
          name: String.t(),
          score: integer(),
          pid: pid(),
          ready?: boolean(),
          selected?: boolean(),
          rules: [School.Logic.rule()]
        }

  defstruct name: nil,
            score: 0,
            pid: nil,
            ready?: false,
            selected?: false,
            rules: []
end

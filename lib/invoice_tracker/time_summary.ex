alias InvoiceTracker.{Detail, ProjectTimeSummary, Rounding, TimeEntry}
alias Timex.Duration

defprotocol InvoiceTracker.TimeEntry do
  @doc """
  Returns the time for the entry
  """

  @spec time(t) :: Duration.t()
  def time(entry)
end

defmodule InvoiceTracker.TimeSummary do
  @moduledoc """
  A struct that summarizes time entries for an invoice period.
  """

  defstruct total: Duration.zero(), projects: []

  @type t :: %__MODULE__{total: Duration.t(), projects: [ProjectTimeSummary.t()]}

  defimpl TimeEntry do
    def time(summary), do: summary.total
  end

  @doc """
  Rounds all of the times in the summary to the nearest tenth of an hour.

  Also reconciles project and detail entries so that, when rounded, they add
  up to the total (rounded) time.

  A TimeSummary should be rounded before reporting on it or generating an
  invoice for it.
  """
  @spec rounded(t) :: t
  def rounded(summary) do
    summary
    |> Map.update!(:total, &Rounding.round_time/1)
    |> reconcile_projects
  end

  defp reconcile_projects(summary) do
    Map.update!(summary, :projects, &ProjectTimeSummary.reconciled(&1, summary.total))
  end
end

defmodule InvoiceTracker.ProjectTimeSummary do
  @moduledoc """
  A struct that summarizes time entries for a single project for an
  invoice period.
  """

  defstruct name: "", time: Duration.zero(), details: []

  @type t :: %__MODULE__{
          name: String.t(),
          time: Duration.t(),
          details: [Detail.t()]
        }

  defimpl TimeEntry do
    def time(summary), do: summary.time
  end

  @doc """
  Reconciles a list of projects with a rounded total time.

  Times are rounded to the nearest tenth of an hour and then adjusted so that,
  when rounded, they add up to the total (rounded) time.

  Each project's details are also reconciled and rounded in the same way once
  the projects themselves have been reconciled and rounded.
  """
  @spec reconciled([t], Duration.t()) :: [t]
  def reconciled(projects, total) do
    projects
    |> Rounding.reconcile(total)
    |> Enum.map(&reconcile_details/1)
  end

  defp reconcile_details(project) do
    Map.update!(project, :details, &Detail.reconciled(&1, project.time))
  end
end

defmodule InvoiceTracker.Detail do
  @moduledoc """
  A struct that represents a project activity detail entry for an
  invoice period.
  """

  defstruct activity: "", time: Duration.zero()

  @type t :: %__MODULE__{activity: String.t(), time: Duration.t()}

  defimpl TimeEntry do
    def time(detail), do: detail.time
  end

  @doc """
  Reconciles a list of detail entries with a rounded total time.

  Times are rounded to the nearest tenth of an hour and then adjusted so that,
  when rounded, they add up to the total (rounded) time.
  """
  @spec reconciled([t], Duration.t()) :: [t]
  def reconciled(details, total), do: Rounding.reconcile(details, total)
end

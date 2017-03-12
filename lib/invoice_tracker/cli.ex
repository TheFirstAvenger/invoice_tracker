defmodule InvoiceTracker.CLI do
  @moduledoc """
  Defines the command-line interface
  """

  use ExCLI.DSL, escript: true

  alias ExCLI.Argument
  alias InvoiceTracker.{DefaultDate, Invoice, Repo, TableFormatter}

  name "invoice"
  description "Invoice tracker"
  long_description ~s"""
  invoice records invoices and payments and produces a report of
  paid and unpaid invoices.
  """

  option :file,
    help: "The invoice data file to use",
    aliases: [:f],
    default: "invoices.ets",
    required: true

  command :record do
    description "Records an invoice"

    argument :number, type: :integer
    argument :amount, type: :float
    option :date,
      help: "The invoice date",
      aliases: [:d],
      default: DefaultDate.for_invoice(),
      process: &__MODULE__.process_date_option/3,
      required: true

    run context do
      start_repo(context)
      invoice = %Invoice{
        number: context.number,
        amount: context.amount,
        date: context.date
      }
      InvoiceTracker.record(invoice)
    end
  end

  command :payment do
    description "Records a payment"

    option :number,
      help: "The invoice number (default: oldest unpaid)",
      aliases: [:n],
      type: :integer

    option :date,
      help: "The invoice date (default: today)",
      aliases: [:d],
      default: DefaultDate.for_payment(),
      process: &__MODULE__.process_date_option/3,
      required: true

    run context do
      start_repo(context)
      number = Map.get(context, :number,
        InvoiceTracker.oldest_unpaid_invoice().number
      )
      InvoiceTracker.pay(number, context.date)
    end
  end

  command :list do
    option :all,
      help: "List all invoices (default: show unpaid only)",
      aliases: [:a],
      default: false,
      type: :boolean

    run context do
      start_repo(context)

      context.all
      |> selected_invoices
      |> Enum.sort_by(&(&1.number))
      |> TableFormatter.format_list
      |> IO.write
    end
  end

  defp selected_invoices(true), do: InvoiceTracker.all()
  defp selected_invoices(_), do: InvoiceTracker.unpaid()

  command :status do
    option :date,
      help: "Show status as of this date (default: today)",
      aliases: [:d],
      default: DefaultDate.for_current_status(),
      process: &__MODULE__.process_date_option/3,
      required: true

    option :since,
      help: "Include activity since this date (default: 1 week ago)",
      aliases: [:s],
      process: &__MODULE__.process_date_option/3

    run context do
      start_repo(context)
      since = context.since || DefaultDate.for_previous_status(context.date)
      since
      |> InvoiceTracker.active_since
      |> Enum.sort_by(&(&1.number))
      |> TableFormatter.format_status(context.date)
      |> IO.write
    end
  end

  def process_date_option(option, context, [{:arg, value} | rest]) do
    date = Date.from_iso8601!(value)
    {:ok, Map.put(context, Argument.key(option), date), rest}
  end

  defp start_repo(context) do
    Repo.start_link_with_file(context.file)
  end
end

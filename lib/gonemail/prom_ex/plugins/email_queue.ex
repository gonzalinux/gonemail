defmodule Gonemail.PromEx.Plugins.EmailQueue do
  use PromEx.Plugin

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 10_000)

    [queue_depth_metrics(poll_rate)]
  end

  @impl true
  def event_metrics(_opts) do
    [email_attempt_events()]
  end

  defp queue_depth_metrics(poll_rate) do
    Polling.build(
      :gonemail_queue_depth,
      poll_rate,
      {__MODULE__, :execute_queue_depth, []},
      [
        last_value(
          [:gonemail, :queue, :pending, :total],
          event_name: [:gonemail, :queue, :depth],
          description: "Number of emails currently queued or retrying",
          measurement: :count
        )
      ]
    )
  end

  defp email_attempt_events do
    Event.build(
      :gonemail_email_attempt_events,
      [
        counter(
          [:gonemail, :email, :attempts, :total],
          event_name: [:gonemail, :email, :attempt],
          description: "Total number of email delivery attempts",
          tags: [:app, :status]
        ),
        distribution(
          [:gonemail, :email, :delivery, :duration, :milliseconds],
          event_name: [:gonemail, :email, :attempt],
          measurement: :duration,
          description: "Email delivery attempt duration in milliseconds",
          unit: {:native, :millisecond},
          tags: [:app, :status],
          reporter_options: [buckets: [50, 100, 250, 500, 1000, 2500, 5000, 10_000, 30_000]]
        )
      ]
    )
  end

  def execute_queue_depth do
    count = Gonemail.Messages.MessageService.count_pending()
    :telemetry.execute([:gonemail, :queue, :depth], %{count: count})
  end
end

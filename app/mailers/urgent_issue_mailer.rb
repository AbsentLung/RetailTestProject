class UrgentIssueMailer < ApplicationMailer
  # No real on-call address configured yet - this is the placeholder that
  # would become a real distribution list if this app went live.
  def notify(exception, context = {})
    @exception = exception
    @context = context

    mail(
      to: ENV.fetch("URGENT_ALERT_EMAIL", "ops@example.com"),
      subject: "[Retail Inventory] #{exception.class}: #{exception.message.to_s.truncate(80)}"
    )
  end
end

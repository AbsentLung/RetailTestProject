# Wired in at the two points where this app's actual job - importing data,
# generating alerts - can fail outright, not at every rescue. A single bad
# CSV row already gets Rails.logger.warn where it's skipped; this is for the
# rarer case where the whole operation didn't complete.
#
# No New Relic account, SMS, or real email address exists for this project
# yet, but this is written the way it would be if it went live: each channel
# checks for its own configuration and no-ops cleanly if it isn't there,
# rather than pretending to call a service that doesn't exist. Email always
# "sends" (delivery_method is :test in development/test, so nothing leaves
# the process); New Relic and SMS only fire if their real credentials show up
# in the environment.
class ErrorReporter
  def self.notify(exception, context: {})
    # The same exception can reach here twice - AlertGenerator re-raises past its
    # own rescue, and the importer's rescue catches that same object again. Mark
    # it reported so a nested caller's re-raise doesn't trigger a second round of
    # channels for what's still one incident.
    return if exception.instance_variable_get(:@_error_reporter_notified)
    exception.instance_variable_set(:@_error_reporter_notified, true)

    Rails.logger.error("[ErrorReporter] #{exception.class}: #{exception.message} #{context.inspect}")

    %i[notify_apm notify_email notify_sms].each do |channel|
      begin
        send(channel, exception, context)
      rescue => reporting_error
        # A broken notification channel must never hide the original error
        # or stop the other channels from getting a chance to fire.
        Rails.logger.error("[ErrorReporter] #{channel} itself failed: #{reporting_error.class}: #{reporting_error.message}")
      end
    end
  end

  def self.notify_apm(exception, context)
    return unless defined?(NewRelic::Agent)

    NewRelic::Agent.notice_error(exception, custom_params: context)
  end
  private_class_method :notify_apm

  def self.notify_email(exception, context)
    UrgentIssueMailer.notify(exception, context).deliver_now
  end
  private_class_method :notify_email

  def self.notify_sms(exception, context)
    return unless ENV["TWILIO_ACCOUNT_SID"].present? && defined?(Twilio::REST::Client)

    Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]).messages.create(
      from: ENV["TWILIO_FROM_NUMBER"],
      to: ENV["URGENT_ALERT_PHONE_NUMBER"],
      body: "[Retail Inventory] #{exception.class}: #{exception.message.to_s.truncate(120)}"
    )
  end
  private_class_method :notify_sms
end

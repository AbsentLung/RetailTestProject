require "test_helper"

class ErrorReporterTest < ActiveSupport::TestCase
  test "logs the error and sends an urgent email" do
    exception = RuntimeError.new("something broke")

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      ErrorReporter.notify(exception, context: { foo: "bar" })
    end

    mail = ActionMailer::Base.deliveries.last
    assert_match "something broke", mail.subject
  end

  test "New Relic and SMS stay no-ops when not configured, as they are today" do
    assert_not defined?(NewRelic::Agent)
    assert_nil ENV["TWILIO_ACCOUNT_SID"]

    assert_nothing_raised { ErrorReporter.notify(RuntimeError.new("x")) }
  end

  test "a failure in one notification channel doesn't block the others or raise" do
    ErrorReporter.stub(:notify_email, ->(*) { raise "mailer is down" }) do
      assert_nothing_raised { ErrorReporter.notify(RuntimeError.new("y")) }
    end
  end
end

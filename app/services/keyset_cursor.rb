# Encodes a (sort value, id) row position as an opaque token for keyset
# pagination - see DESIGN_PROPOSAL_FINAL.md's infinite-scroll section. The
# token is base64, not encryption: it's meant to be unguessable-by-accident
# and self-validating, not to hide the row position from a motivated client.
#
# Typed, not just stringified: the sort value can be a timestamp, a name
# string, or a boolean (sorting alerts by status) - encode/decode need to
# round-trip the real type, not just "whatever came back from Base64".
module KeysetCursor
  class InvalidToken < StandardError; end

  def self.encode(value, id)
    type, encoded = case value
    when Time, DateTime, ActiveSupport::TimeWithZone
      ["time", value.to_time.utc.iso8601(6)]
    when true, false
      ["bool", value]
    when Integer
      ["int", value]
    else
      ["str", value.to_s]
    end
    Base64.urlsafe_encode64(JSON.generate([type, encoded, id]), padding: false)
  end

  def self.decode(token)
    parsed = JSON.parse(Base64.urlsafe_decode64(token))
    raise InvalidToken, "malformed cursor" unless parsed.is_a?(Array) && parsed.size == 3

    type, raw_value, id = parsed
    value = case type
    when "time" then Time.iso8601(raw_value)
    when "bool" then raw_value == true
    when "int" then Integer(raw_value)
    when "str" then raw_value.to_s
    else raise InvalidToken, "unknown cursor value type"
    end
    [value, Integer(id)]
  rescue ArgumentError, TypeError, JSON::ParserError
    raise InvalidToken, "malformed cursor"
  end
end

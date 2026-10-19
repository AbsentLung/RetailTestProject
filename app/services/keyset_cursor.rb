# Encodes a (timestamp, id) row position as an opaque token for keyset
# pagination - see DESIGN_PROPOSAL_FINAL.md's infinite-scroll section. The
# token is base64, not encryption: it's meant to be unguessable-by-accident
# and self-validating, not to hide the row position from a motivated client.
module KeysetCursor
  class InvalidToken < StandardError; end

  def self.encode(time, id)
    # JSON, not a delimited string: an ISO8601 timestamp already contains
    # colons, so joining "time:id" with ":" and splitting on it back apart
    # is ambiguous - it silently split the timestamp itself in testing.
    Base64.urlsafe_encode64(JSON.generate([time.utc.iso8601(6), id]), padding: false)
  end

  def self.decode(token)
    parsed = JSON.parse(Base64.urlsafe_decode64(token))
    raise InvalidToken, "malformed cursor" unless parsed.is_a?(Array) && parsed.size == 2

    time_str, id = parsed
    [Time.iso8601(time_str), Integer(id)]
  rescue ArgumentError, TypeError, JSON::ParserError
    raise InvalidToken, "malformed cursor"
  end
end

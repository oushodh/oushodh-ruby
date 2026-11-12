# frozen_string_literal: true

require "net/http"
require "openssl"

module Oushodh
  # The default transport, on Net::HTTP. A transport is any object with `get(uri, headers:, timeout:)` that
  # returns a Response, or raises ConnectionError or TimeoutError when no answer comes back.
  class Transport
    def get(uri, headers:, timeout:)
      http = Net::HTTP.new(uri.host, uri.port)

      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout
      http.max_retries = 0 # the client does its own retries

      response = http.start { |connection| connection.get(uri.request_uri, headers) }

      Response.new(status: response.code.to_i, headers: response.to_hash.transform_values(&:first),
                   body: response.body || "")
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
      raise TimeoutError, "The request timed out"
    rescue IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise ConnectionError, "Could not reach the API: #{e.class}"
    end
  end
end

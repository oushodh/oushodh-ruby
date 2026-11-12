# frozen_string_literal: true

require "json"
require "uri"

module Oushodh
  # The Oushodh API client.
  #
  # `api_key` defaults to the OUSHODH_API_KEY environment variable. Pass `transport:` to send requests your own
  # way, for example a fake one in tests.
  class Client
    DEFAULT_BASE_URL = "https://api.oushodh.dev"
    DEFAULT_TIMEOUT = 30
    DEFAULT_MAX_RETRIES = 2

    ERRORS = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => PermissionDeniedError,
      404 => NotFoundError
    }.freeze

    attr_reader :base_url, :timeout, :max_retries

    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES, transport: Transport.new)
      key = api_key || ENV.fetch("OUSHODH_API_KEY", nil)

      if key.nil? || key.empty?
        raise Error, "No API key: pass api_key: or set the OUSHODH_API_KEY environment variable"
      end

      @api_key = key
      @base_url = base_url.chomp("/")
      @timeout = timeout
      @max_retries = max_retries
      @transport = transport
    end

    def inspect
      "#<#{self.class.name} base_url=#{@base_url.inspect}>"
    end

    alias to_s inspect

    def meta
      Meta.new(get_json("/v1/meta"))
    end

    def list_medicines(limit: nil, cursor: nil, updated_since: nil, q: nil)
      params = { limit: limit, cursor: cursor, updated_since: format_since(updated_since), q: q }

      Page.new(get_json("/v1/medicines", params))
    end

    # Every medicine, page after page to the end. Without a block it returns an Enumerator that fetches each
    # page only when it is needed.
    def medicines(limit: nil, updated_since: nil, q: nil, &block)
      unless block_given?
        return enum_for(:medicines, limit: limit, updated_since: updated_since, q: q)
      end

      cursor = nil

      loop do
        page = list_medicines(limit: limit, cursor: cursor, updated_since: updated_since, q: q)

        page.items.each(&block)
        cursor = page.next

        if cursor.nil?
          break
        end
      end
    end

    def search(query, limit: nil)
      SearchResult.new(get_json("/v1/medicines/search", { q: query, limit: limit }))
    end

    def get_medicine(ref)
      MedicineDetail.new(get_json("/v1/medicines/#{escape(ref)}"))
    end

    # The address of a picture, as `product_image` gives it. It needs no key.
    def image_url(file)
      "#{@base_url}/v1/images/#{escape(file)}"
    end

    # The picture's bytes, as a binary String. It sends no key.
    def get_image(file)
      request("/v1/images/#{escape(file)}", {}, auth: false).body
    end

    private

    def get_json(path, params = {})
      JSON.parse(request(path, params, auth: true).body)
    end

    def request(path, params, auth:)
      uri = URI("#{@base_url}#{path}")
      query = params.compact

      unless query.empty?
        uri.query = URI.encode_www_form(query)
      end

      attempt = 0

      loop do
        error = nil

        begin
          response = @transport.get(uri, headers: headers(auth), timeout: @timeout)
        rescue ConnectionError => e
          error = e
        else
          if response.status.between?(200, 299)
            return response
          end

          error = api_error(response)
        end

        delay = retry_delay(error, attempt)

        if delay.nil?
          raise error
        end

        sleep(delay)
        attempt += 1
      end
    end

    def headers(auth)
      headers = { "User-Agent" => "oushodh-ruby/#{VERSION}" }

      if auth
        headers["Authorization"] = "Bearer #{@api_key}"
        headers["Accept"] = "application/json"
      end

      headers
    end

    def retry_delay(error, attempt)
      if attempt >= @max_retries
        return nil
      end

      # quota_exceeded waits until next month, so only rate_limited is retried.
      if error.is_a?(RateLimitError)
        return error.code == "rate_limited" ? error.retry_after || backoff(attempt) : nil
      end

      if error.is_a?(InternalServerError) || error.is_a?(ConnectionError)
        return backoff(attempt)
      end

      nil
    end

    def backoff(attempt)
      [0.5 * (2**attempt), 8.0].min * rand(0.5..1.0)
    end

    def api_error(response)
      status = response.status
      code, message = error_detail(response.body)
      message ||= "HTTP #{status}"

      if status == 429
        return RateLimitError.new(message, status: status, code: code, retry_after: retry_after(response))
      end

      kind = ERRORS.fetch(status) { status >= 500 ? InternalServerError : Error }

      kind.new(message, status: status, code: code)
    end

    def error_detail(body)
      detail = JSON.parse(body)["error"]

      unless detail.is_a?(Hash)
        return [nil, nil]
      end

      code = detail["code"].is_a?(String) ? detail["code"] : nil
      message = detail["message"].is_a?(String) ? detail["message"] : nil

      [code, message]
    rescue JSON::ParserError, TypeError, NoMethodError
      [nil, nil]
    end

    def retry_after(response)
      Float(response.headers["retry-after"], exception: false)
    end

    def format_since(value)
      if value.nil? || value.is_a?(String)
        return value
      end

      value.to_time.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    def escape(part)
      part.to_s.b.gsub(/[^A-Za-z0-9\-._~]/n) { |char| format("%%%02X", char.ord) }
    end
  end
end

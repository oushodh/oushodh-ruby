# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "oushodh"
require "minitest/autorun"
require "webrick"
require "json"

# A local HTTP server that answers with queued replies and records each request. It never calls the real API.
class FakeAPI
  Request = Data.define(:path, :query, :headers)

  attr_reader :requests

  def initialize
    @requests = []
    @replies = []
    started = Queue.new
    @server = WEBrick::HTTPServer.new(
      Port: 0, BindAddress: "127.0.0.1", Logger: WEBrick::Log.new(File::NULL), AccessLog: [],
      StartCallback: -> { started << true }
    )
    @server.mount_proc("/") { |request, response| answer(request, response) }
    @thread = Thread.new { @server.start }
    started.pop
  end

  def url
    "http://127.0.0.1:#{@server.config[:Port]}"
  end

  def reply(status, body = "", headers: {}, wait: nil)
    unless body.is_a?(String)
      body = JSON.generate(body)
      headers = { "Content-Type" => "application/json" }.merge(headers)
    end

    @replies << [status, body, headers, wait]
  end

  def stop
    @server.shutdown
    @thread.join
  end

  private

  def answer(request, response)
    @requests << Request.new(path: request.request_uri.path, query: request.query, headers: request.header)
    status, body, headers, wait = @replies.shift || [500, "no reply queued", {}, nil]

    if wait
      sleep(wait)
    end

    response.status = status
    headers.each { |name, value| response[name] = value }
    response.body = body
  end
end

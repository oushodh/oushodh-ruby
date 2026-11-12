# frozen_string_literal: true

module Oushodh
  # What a transport answers: the HTTP status, the headers with lower-case names, and the body.
  Response = Data.define(:status, :headers, :body)
end

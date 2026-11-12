# frozen_string_literal: true

require_relative "oushodh/version"

require_relative "oushodh/errors/error"
require_relative "oushodh/errors/bad_request_error"
require_relative "oushodh/errors/authentication_error"
require_relative "oushodh/errors/permission_denied_error"
require_relative "oushodh/errors/not_found_error"
require_relative "oushodh/errors/rate_limit_error"
require_relative "oushodh/errors/internal_server_error"
require_relative "oushodh/errors/connection_error"
require_relative "oushodh/errors/timeout_error"

require_relative "oushodh/models/model"
require_relative "oushodh/models/unit_price"
require_relative "oushodh/models/unit_amount"
require_relative "oushodh/models/size_amount"
require_relative "oushodh/models/strip_amount"
require_relative "oushodh/models/pack_amount"
require_relative "oushodh/models/prices"
require_relative "oushodh/models/medicine"
require_relative "oushodh/models/monograph"
require_relative "oushodh/models/medicine_detail"
require_relative "oushodh/models/page"
require_relative "oushodh/models/search_result"
require_relative "oushodh/models/meta"

require_relative "oushodh/http/response"
require_relative "oushodh/http/retry"
require_relative "oushodh/http/transport"

require_relative "oushodh/client"

# The Ruby SDK for the Oushodh medicine data API.
module Oushodh
end

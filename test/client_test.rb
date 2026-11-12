# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  KEY = "oush_test_123"

  MEDICINE = {
    "id" => "MED-012933",
    "uuid" => "01a1ba6f-f4d6-7143-ac84-9376f520eef8",
    "brand" => "Napa",
    "category" => nil,
    "product_name" => "Napa 500 mg Tablet",
    "product_image" => nil,
    "images" => [],
    "unit" => "Strip",
    "size" => "10 Tablets",
    "price" => 12.0,
    "price_per" => "strip",
    "price_source" => "dgda_price",
    "unit_prices" => [{ "size" => "15 gm in Tube Pack", "price" => 110.0 }],
    "prices" => {
      "currency" => "BDT",
      "unit" => { "amount" => 1.2, "source" => "dgda_price" },
      "sizes" => [],
      "strip" => { "amount" => 12.0, "units" => 10, "source" => "dgda_price" },
      "packs" => [{ "amount" => 360.0, "units" => 300, "label" => "300's pack", "source" => "dgda_price" }]
    },
    "description_en" => nil,
    "description_bn" => nil,
    "dosage_form" => "Tablet",
    "strength" => "500 mg",
    "generic_name" => "Paracetamol",
    "manufacturer" => "Beximco Pharmaceuticals PLC.",
    "source_url" => nil,
    "last_updated" => "2026-11-09T15:27:34Z",
    "dgda_listed" => true,
    "medicine_type" => "allopathic",
    "field_added_later" => "kept"
  }.freeze

  def setup
    @api = FakeAPI.new
    @slept = []
  end

  def teardown
    @api.stop
  end

  def client(**)
    client = Oushodh::Client.new(api_key: KEY, base_url: @api.url, **)
    slept = @slept

    client.define_singleton_method(:sleep) { |seconds| slept << seconds }

    client
  end

  def error_body(code, message = "Something")
    { "error" => { "code" => code, "message" => message } }
  end

  def test_meta_sends_the_key_and_user_agent
    @api.reply(200, { "client" => "acme", "id_profile" => "default", "medicines" => 58_937, "last_import" => nil })

    meta = client.meta
    request = @api.requests.first

    assert_equal "/v1/meta", request.path
    assert_equal ["Bearer #{KEY}"], request.headers["authorization"]
    assert_equal ["oushodh-ruby/#{Oushodh::VERSION}"], request.headers["user-agent"]
    assert_equal ["application/json"], request.headers["accept"]
    assert_equal "acme", meta.client
    assert_equal 58_937, meta.medicines
    assert_nil meta.last_import
  end

  def test_list_medicines_sends_every_parameter
    @api.reply(200, { "items" => [MEDICINE], "next" => "abc", "total" => 1 })

    since = Time.new(2026, 11, 8, 15, 30, 0.75, "+06:00")
    page = client.list_medicines(limit: 500, cursor: "c1", updated_since: since, q: "napa 500")
    request = @api.requests.first

    assert_equal "/v1/medicines", request.path
    assert_equal({ "limit" => "500", "cursor" => "c1", "updated_since" => "2026-11-08T09:30:00Z", "q" => "napa 500" },
                 request.query)
    assert_equal "abc", page.next
    assert_equal 1, page.total
  end

  def test_list_medicines_sends_no_empty_parameters
    @api.reply(200, { "items" => [], "next" => nil, "total" => 0 })

    client.list_medicines(updated_since: "2026-11-08T09:30:00Z")

    assert_equal({ "updated_since" => "2026-11-08T09:30:00Z" }, @api.requests.first.query)
  end

  def test_models_read_fields_and_keep_unknown_ones
    @api.reply(200, { "items" => [MEDICINE], "next" => nil, "total" => 1 })

    medicine = client.list_medicines.items.first

    assert_instance_of Oushodh::Medicine, medicine
    assert_equal "Napa 500 mg Tablet", medicine.product_name
    assert_equal "allopathic", medicine.medicine_type
    assert medicine.dgda_listed
    assert_in_delta 1.2, medicine.prices.unit.amount
    assert_equal 10, medicine.prices.strip.units
    assert_equal "300's pack", medicine.prices.packs.first.label
    assert_empty medicine.prices.sizes
    assert_equal "15 gm in Tube Pack", medicine.unit_prices.first.size
    assert_equal "kept", medicine["field_added_later"]
    assert_equal "kept", medicine.to_h["field_added_later"]
    assert_equal "BDT", medicine.dig(:prices, "currency")
  end

  def test_medicines_pages_to_the_end
    @api.reply(200, { "items" => [MEDICINE, MEDICINE], "next" => "page2", "total" => 3 })
    @api.reply(200, { "items" => [MEDICINE], "next" => nil, "total" => 3 })

    medicines = client.medicines(limit: 2, q: "napa").to_a

    assert_equal 3, medicines.length
    assert_equal({ "limit" => "2", "q" => "napa" }, @api.requests[0].query)
    assert_equal({ "limit" => "2", "q" => "napa", "cursor" => "page2" }, @api.requests[1].query)
  end

  def test_medicines_fetches_a_page_only_when_needed
    @api.reply(200, { "items" => [MEDICINE, MEDICINE], "next" => "page2", "total" => 4 })

    medicines = client.medicines

    assert_instance_of Enumerator, medicines
    assert_empty @api.requests
    assert_equal 2, medicines.first(2).length
    assert_equal 1, @api.requests.length
  end

  def test_medicines_takes_a_block
    @api.reply(200, { "items" => [MEDICINE], "next" => nil, "total" => 1 })

    ids = []

    client.medicines { |medicine| ids << medicine.id }

    assert_equal ["MED-012933"], ids
  end

  def test_search
    @api.reply(200, { "items" => [MEDICINE], "total" => 42 })

    result = client.search("napa", limit: 5)
    request = @api.requests.first

    assert_equal "/v1/medicines/search", request.path
    assert_equal({ "q" => "napa", "limit" => "5" }, request.query)
    assert_equal 42, result.total
    assert_equal "Napa", result.items.first.brand
  end

  def test_get_medicine_escapes_the_ref_and_reads_the_monograph
    monograph = { "source" => "example_source", "indications" => "Fever", "composition" => nil }

    @api.reply(200, MEDICINE.merge("monograph" => monograph))

    detail = client.get_medicine("MED 1/2")

    assert_equal "/v1/medicines/MED%201%2F2", @api.requests.first.path
    assert_instance_of Oushodh::MedicineDetail, detail
    assert_equal "Fever", detail.monograph.indications
    assert_nil detail.monograph.composition
  end

  def test_get_medicine_with_no_monograph
    @api.reply(200, MEDICINE.merge("monograph" => nil))

    assert_nil client.get_medicine("MED-012933").monograph
  end

  def test_images_need_no_key
    jpeg = "\xFF\xD8\xFF\xE0".b
    file = "#{"a" * 64}.jpg"

    @api.reply(200, jpeg, headers: { "Content-Type" => "image/jpeg" })

    body = client.get_image(file)
    request = @api.requests.first

    assert_equal jpeg, body.b
    assert_equal "/v1/images/#{file}", request.path
    assert_empty request.headers.fetch("authorization", [])
    assert_equal "#{@api.url}/v1/images/#{file}", client.image_url(file)
    assert_equal "#{@api.url}/v1/images/a%2Fb.jpg", client.image_url("a/b.jpg")
  end

  def test_each_error_family
    families = {
      400 => [Oushodh::BadRequestError, "bad_request"],
      401 => [Oushodh::AuthenticationError, "unauthorized"],
      403 => [Oushodh::PermissionDeniedError, "plan_limit"],
      404 => [Oushodh::NotFoundError, "not_found"],
      429 => [Oushodh::RateLimitError, "quota_exceeded"],
      500 => [Oushodh::InternalServerError, "internal"]
    }

    families.each do |status, (kind, code)|
      @api.reply(status, error_body(code, "Message #{status}"))

      error = assert_raises(kind) { client(max_retries: 0).meta }

      assert_kind_of Oushodh::Error, error
      assert_equal status, error.status
      assert_equal code, error.code
      assert_equal "Message #{status}", error.message
    end
  end

  def test_rate_limited_waits_for_retry_after
    @api.reply(429, error_body("rate_limited"), headers: { "Retry-After" => "3" })
    @api.reply(200, { "client" => "acme", "id_profile" => "default", "medicines" => 1, "last_import" => nil })

    assert_equal "acme", client.meta.client
    assert_equal [3.0], @slept
    assert_equal 2, @api.requests.length
  end

  def test_quota_exceeded_is_raised_at_once
    @api.reply(429, error_body("quota_exceeded"), headers: { "Retry-After" => "86400" })

    error = assert_raises(Oushodh::RateLimitError) { client.meta }

    assert_equal "quota_exceeded", error.code
    assert_in_delta 86_400.0, error.retry_after
    assert_empty @slept
    assert_equal 1, @api.requests.length
  end

  def test_server_error_is_retried_then_succeeds
    @api.reply(503, error_body("internal"))
    @api.reply(200, { "items" => [], "total" => 0 })

    assert_equal 0, client.search("napa").total
    assert_equal 1, @slept.length
    assert_operator @slept.first, :<=, 0.5
    assert_equal 2, @api.requests.length
  end

  def test_retries_stop_at_max_retries
    3.times { @api.reply(500, error_body("internal")) }

    assert_raises(Oushodh::InternalServerError) { client(max_retries: 2).meta }
    assert_equal 3, @api.requests.length
  end

  def test_not_found_is_not_retried
    @api.reply(404, error_body("not_found"))

    assert_raises(Oushodh::NotFoundError) { client.get_medicine("MED-999999") }
    assert_equal 1, @api.requests.length
    assert_empty @slept
  end

  def test_an_error_body_that_is_not_json
    @api.reply(418, "<html>teapot</html>")

    error = assert_raises(Oushodh::Error) { client.meta }

    assert_instance_of Oushodh::Error, error
    assert_equal 418, error.status
    assert_nil error.code
    assert_equal "HTTP 418", error.message
  end

  def test_network_error
    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    client = Oushodh::Client.new(api_key: KEY, base_url: "http://127.0.0.1:#{port}", max_retries: 0)

    error = assert_raises(Oushodh::ConnectionError) { client.meta }

    assert_nil error.status
    assert_nil error.code
  end

  def test_timeout
    @api.reply(200, { "client" => "acme" }, wait: 1)

    assert_raises(Oushodh::TimeoutError) { client(timeout: 0.2, max_retries: 0).meta }
  end

  def test_the_key_never_appears_in_errors
    @api.reply(401, error_body("unauthorized", "A valid API key is required"))

    client = client(max_retries: 0)
    error = assert_raises(Oushodh::AuthenticationError) { client.meta }
    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    offline = Oushodh::Client.new(api_key: KEY, base_url: "http://127.0.0.1:#{port}", max_retries: 0)
    network = assert_raises(Oushodh::ConnectionError) { offline.meta }

    [error.full_message, error.inspect, network.full_message, client.inspect, client.to_s].each do |text|
      refute_includes text, KEY
    end
  end

  def test_the_key_comes_from_the_environment
    previous = ENV.fetch("OUSHODH_API_KEY", nil)

    ENV["OUSHODH_API_KEY"] = KEY
    @api.reply(200, { "client" => "acme" })
    Oushodh::Client.new(base_url: @api.url).meta

    assert_equal ["Bearer #{KEY}"], @api.requests.first.headers["authorization"]

    ENV.delete("OUSHODH_API_KEY")

    error = assert_raises(Oushodh::Error) { Oushodh::Client.new }

    assert_includes error.message, "OUSHODH_API_KEY"
  ensure
    ENV["OUSHODH_API_KEY"] = previous
  end

  def test_a_custom_transport
    transport = Object.new
    seen = []

    transport.define_singleton_method(:get) do |uri, headers:, timeout:|
      seen << [uri.to_s, headers["Authorization"], timeout]

      Oushodh::Response.new(status: 200, headers: {}, body: '{"client":"acme"}')
    end

    meta = Oushodh::Client.new(api_key: KEY, base_url: "https://api.example.test/", timeout: 5,
                               transport: transport).meta

    assert_equal "acme", meta.client
    assert_equal [["https://api.example.test/v1/meta", "Bearer #{KEY}", 5]], seen
  end
end

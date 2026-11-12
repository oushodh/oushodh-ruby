# Oushodh for Ruby

The Ruby SDK for the Oushodh medicine data API: medicine data for Bangladesh, checked against the DGDA register.

- Ruby 3.3 or newer.
- No runtime dependencies: it uses `net/http` and `json` from the standard library.
- One client, `Oushodh::Client`, with an `Enumerator` that pages for you.

The full API reference is at [oushodh.dev/docs](https://oushodh.dev/docs).

## Install

Install from GitHub for now. Add this line to your `Gemfile`:

```ruby
gem "oushodh", git: "https://github.com/oushodh/oushodh-ruby.git"
```

Then run `bundle install`.

Install from RubyGems is coming soon (`gem install oushodh`).

## Quickstart

Make an API key on the Keys page of the member portal at [app.oushodh.dev](https://app.oushodh.dev). A key starts
with `oush_` and is shown once. Keep it on your server: a key inside an app can be copied out of it.

```ruby
require "oushodh"

client = Oushodh::Client.new(api_key: "oush_...") # or set OUSHODH_API_KEY and call Oushodh::Client.new

p client.meta # check that the key works

result = client.search("napa 500", limit: 5)

result.items.each do |medicine|
  puts [medicine.id, medicine.product_name, medicine.prices.unit&.amount].join(" ")
end

detail = client.get_medicine("MED-012933")
puts detail.monograph&.indications
```

The client takes these options:

| Option        | Default                   | What it does                                       |
| ------------- | ------------------------- | -------------------------------------------------- |
| `api_key:`    | `OUSHODH_API_KEY`         | Your API key. With no key, the client raises.      |
| `base_url:`   | `https://api.oushodh.dev` | Where the API is.                                  |
| `timeout:`    | `30`                      | Seconds to wait for each request.                  |
| `max_retries:`| `2`                       | Retries after a `429 rate_limited`, a `5xx` or a network error. |
| `transport:`  | `Oushodh::Transport.new`  | Sends the requests, on `Net::HTTP`. Pass your own, for example in tests. |

A transport is any object with `get(uri, headers:, timeout:)` that returns an `Oushodh::Response` (`status`,
`headers` with lower-case names, `body`). It raises `Oushodh::ConnectionError` or `Oushodh::TimeoutError` when no
answer comes back.

## Methods

| Method                                                | Route                          | Returns          |
| ----------------------------------------------------- | ------------------------------ | ---------------- |
| `meta`                                                | `GET /v1/meta`                 | `Meta`           |
| `list_medicines(limit:, cursor:, updated_since:, q:)` | `GET /v1/medicines`            | `Page`           |
| `medicines(limit:, updated_since:, q:)`               | `GET /v1/medicines`, each page | an `Enumerator` of `Medicine` |
| `search(q, limit:)`                                   | `GET /v1/medicines/search`     | `SearchResult`   |
| `get_medicine(ref)`                                   | `GET /v1/medicines/{ref}`      | `MedicineDetail` |
| `image_url(file)`                                     | none                           | the picture's address |
| `get_image(file)`                                     | `GET /v1/images/{file}`        | the picture's bytes, as a binary `String` |

Every keyword is optional. `ref` is a medicine's ID in any profile, an old ID, or its UUID. The answer always carries
the medicine's current ID.

### Models

`Meta`, `Page`, `SearchResult`, `Medicine`, `MedicineDetail`, `Monograph` and `Prices` have a reader for each field
the API documents, with the API's own names: `medicine.product_name`, `medicine.prices.strip&.amount`,
`page.next`. A value no source gives is `nil`. Times, such as `last_updated`, stay strings like
`2026-11-09T15:27:34Z`.

Each model keeps the whole JSON object, so fields the API adds later are kept too. Read them with `[]` or `dig`, or
get the hash with `to_h`:

```ruby
medicine["a_new_field"]
medicine.dig("prices", "currency")
medicine.to_h
```

## Paging

`list_medicines` gives one page: `items`, `next` and `total`. Pass `next` back as `cursor` for the next page. `next`
is `nil` on the last page. A page holds 1 to 500 medicines (`limit:`, default 100).

`medicines` does this for you, page after page to the end. With a block, it yields each medicine. Without one, it
returns an `Enumerator` that fetches each page only when it needs it:

```ruby
client.medicines(limit: 500).each do |medicine|
  save(medicine)
end

first_ten = client.medicines(q: "napa").first(10) # fetches one page
```

Search has no cursor. To page every match, use `medicines(q: ...)`.

## Sync

Copy the whole database once, then fetch only what changed.

1. The first sync pages through `medicines` to the end. Keep the `last_updated` of the newest medicine.
2. Each later sync passes that time as `updated_since:` and pages to the end. Medicines come oldest change first.

```ruby
since = load_last_sync # such as "2026-11-08T09:30:00Z", or nil the first time

client.medicines(limit: 500, updated_since: since).each do |medicine|
  upsert(medicine.uuid, medicine.to_h)
  since = [since, medicine.last_updated].compact.max
end

store_last_sync(since)
```

`updated_since:` takes a string like `2026-11-08T09:30:00Z`, or a `Time` (or anything with `to_time`), which the SDK
sends in UTC to the whole second. It means "at or after", so the medicine that set the time comes back once more.
Store each medicine by its `uuid`: it never changes. Medicines are never deleted and IDs are never reused.

## Errors

Every error is an `Oushodh::Error`. It has `status` (the HTTP status), `code` (the API's error code) and `message`.
Match on `code` or on the class, never on `message`: the message is for people and may change. When an error answer
is not JSON, `code` is `nil` and `message` is `HTTP <status>`.

| Class                            | Status | `code`                             |
| -------------------------------- | ------ | ---------------------------------- |
| `Oushodh::BadRequestError`       | 400    | `bad_request`                      |
| `Oushodh::AuthenticationError`   | 401    | `unauthorized`                     |
| `Oushodh::PermissionDeniedError` | 403    | `plan_expired` or `plan_limit`     |
| `Oushodh::NotFoundError`         | 404    | `not_found`                        |
| `Oushodh::RateLimitError`        | 429    | `rate_limited` or `quota_exceeded` |
| `Oushodh::InternalServerError`   | 5xx    | `internal`                         |
| `Oushodh::ConnectionError`       | none   | none: the network failed           |
| `Oushodh::TimeoutError`          | none   | none: the request timed out        |

`TimeoutError` is a kind of `ConnectionError`.

```ruby
begin
  medicine = client.get_medicine("MED-012933")
rescue Oushodh::NotFoundError
  medicine = nil
rescue Oushodh::PermissionDeniedError => e
  warn "Upgrade your plan to read this medicine." if e.code == "plan_limit"
  raise
end
```

The SDK retries a `429 rate_limited`, a `5xx` and a network error up to `max_retries` times. After a `5xx` or a
network error it waits a little longer each time. It never retries any other `4xx`: they give the same answer every
time. The error message never holds your key.

## Rate limits

Your plan sets how many requests each key may make in a minute (60 a minute on Developer), and how many your account
may make in a month.

- Over the minute's limit, the API answers `429 rate_limited`. The `Retry-After` header says how many seconds to wait.
  The SDK waits that long and tries again.
- When the month's requests are used up, the API answers `429 quota_exceeded` until the next month. The SDK raises it
  at once and never waits. `Oushodh::RateLimitError#retry_after` holds the seconds to the next month.

## Plan limits

Some plans read only the first medicines, in the order of their permanent number. Lists and search leave out the rest.
A lookup by ID of such a medicine raises `Oushodh::PermissionDeniedError` with `code` `plan_limit`.
`client.meta.medicines` says how many medicines your key reads.

## Images

`product_image` is the address of a medicine's picture. When it is under `/v1/images/`, Oushodh keeps the copy and
serves it with no key, so an `<img>` tag can show it. The file never changes, so it can be cached for a year.

```ruby
url = medicine.product_image

if url&.start_with?(client.image_url(""))
  jpeg = client.get_image(url.split("/").last)
  File.binwrite("#{medicine.uuid}.jpg", jpeg)
end
```

`get_image` takes the file name, not the whole address. Any other address belongs to the source, and it can move or be
removed.

## Develop

```sh
bundle install
bundle exec rubocop
bundle exec rake test
```

`bundle exec rake` runs both. The tests use a local WEBrick server. They never call the API.

## License

MIT. See [LICENSE](LICENSE).

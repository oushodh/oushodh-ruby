# Oushodh for Ruby

[![CI](https://github.com/oushodh/oushodh-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/oushodh/oushodh-ruby/actions/workflows/ci.yml)

The official Ruby SDK for the [Oushodh](https://oushodh.dev) medicine data API. Oushodh gives you medicine data for
Bangladesh, checked against the DGDA register: brands, generics, strengths, dosage forms, manufacturers, MRPs,
pictures and medical text.

- Ruby 3.3 or newer.
- No runtime dependencies. It uses `net/http` and `json` from the standard library.
- One client, `Oushodh::Client`, with typed models, errors by family, retries and an `Enumerator` that pages for you.

The full API reference is at [oushodh.dev/docs](https://oushodh.dev/docs).

## Contents

- [Install](#install)
- [Get an API key](#get-an-api-key)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Methods](#methods)
- [Models](#models)
- [Paging](#paging)
- [Sync](#sync)
- [Errors](#errors)
- [Retries and rate limits](#retries-and-rate-limits)
- [Plan limits](#plan-limits)
- [Images](#images)
- [Develop](#develop)
- [Release](#release)
- [Links](#links)
- [License](#license)

## Install

Install it from [RubyGems](https://rubygems.org/gems/oushodh). Add this line to your `Gemfile`:

```ruby
gem "oushodh", "~> 0.1"
```

Then run `bundle install`. Without Bundler, run `gem install oushodh`.

## Get an API key

Make a key on the Keys page at [app.oushodh.dev](https://app.oushodh.dev). A key starts with `oush_` and is shown
once, so copy it then. Keep it on your server: a key inside an app can be copied out of it.

The client reads the key from `api_key:`, or from the `OUSHODH_API_KEY` environment variable when you pass none.

## Quick start

```ruby
require "oushodh"

client = Oushodh::Client.new # reads OUSHODH_API_KEY

result = client.search("napa 500", limit: 5)

result.items.each do |medicine|
  puts [medicine.id, medicine.product_name, medicine.prices.strip&.amount].join(" ")
end

detail = client.get_medicine("MED-012933")
puts detail.monograph&.indications
```

## Configuration

```ruby
client = Oushodh::Client.new(
  api_key: "oush_...",
  base_url: "https://api.oushodh.dev",
  timeout: 30,
  max_retries: 2
)
```

| Option         | Default                   | What it does                                                                        |
| -------------- | ------------------------- | ----------------------------------------------------------------------------------- |
| `api_key:`     | `OUSHODH_API_KEY`         | Your API key. With no key at all, `Client.new` raises `Oushodh::Error`.             |
| `base_url:`    | `https://api.oushodh.dev` | Where the API is.                                                                   |
| `timeout:`     | `30`                      | Seconds to wait for each request.                                                   |
| `max_retries:` | `2`                       | Retries after a `429 rate_limited`, a `5xx` or a network error. `0` turns them off. |
| `transport:`   | `Oushodh::Transport.new`  | Sends the requests, on `Net::HTTP`. Pass your own, for example in tests.            |

A transport is any object with `get(uri, headers:, timeout:)` that returns an `Oushodh::Response` (`status`,
`headers` with lower-case names, `body`). It raises `Oushodh::ConnectionError` or `Oushodh::TimeoutError` when no
answer comes back.

```ruby
class FakeTransport
  def get(uri, headers:, timeout:)
    Oushodh::Response.new(status: 200, headers: {}, body: '{"client":"test"}')
  end
end

client = Oushodh::Client.new(api_key: "oush_test_123", transport: FakeTransport.new)
client.meta.client # => "test"
```

The client never prints your key: `inspect` and `to_s` leave it out, and no error message holds it.

## Methods

| Method                                                | Route                          | Returns                                   |
| ----------------------------------------------------- | ------------------------------ | ----------------------------------------- |
| `meta`                                                | `GET /v1/meta`                 | `Meta`                                    |
| `list_medicines(limit:, cursor:, updated_since:, q:)` | `GET /v1/medicines`            | `Page`                                    |
| `medicines(limit:, updated_since:, q:)`               | `GET /v1/medicines`, each page | an `Enumerator` of `Medicine`             |
| `search(q, limit:)`                                   | `GET /v1/medicines/search`     | `SearchResult`                            |
| `get_medicine(ref)`                                   | `GET /v1/medicines/{ref}`      | `MedicineDetail`                          |
| `image_url(file)`                                     | none                           | the picture's address, as a `String`      |
| `get_image(file)`                                     | `GET /v1/images/{file}`        | the picture's bytes, as a binary `String` |

Every keyword is optional.

### meta

The account your key belongs to. Call it to check that the key works.

```ruby
meta = client.meta

meta.client      # the account the key belongs to
meta.id_profile  # the ID profile your medicine IDs come from
meta.medicines   # how many medicines your key reads
meta.last_import # when the data was last imported, such as "2026-11-09T15:27:40Z"
```

### list_medicines

One page of medicines. `limit:` is 1 to 500 (default 100). `q:` filters by name, and `updated_since:` keeps only
medicines changed at or after a time.

```ruby
page = client.list_medicines(limit: 100, q: "paracetamol")

page.items.size # up to 100
page.total      # every match, across all pages
page.next       # pass it back as cursor:, or nil on the last page

following = client.list_medicines(limit: 100, q: "paracetamol", cursor: page.next)
```

### medicines

Every medicine, page after page to the end. See [Paging](#paging).

```ruby
client.medicines(q: "napa").each { |medicine| puts medicine.product_name }
```

### search

The best matches for what a person typed, best match first. `limit:` is 1 to 50 (default 20). When `q` is an ID or a
UUID, the answer is that one medicine.

```ruby
result = client.search("napa", limit: 10)

result.items.first&.product_name
result.total # every match, including those past limit
```

Search has no cursor. To page every match, use `medicines(q: ...)`.

### get_medicine

One medicine with its medical text. `ref` is a medicine's ID in any profile, an old ID, or its UUID. The answer
always carries the medicine's current ID.

```ruby
detail = client.get_medicine("01a1ba6f-f4d6-7143-ac84-9376f520eef8")

detail.id # its current ID
detail.monograph&.dosage
detail.monograph&.side_effects
```

`monograph` is `nil` when no source gives medical text.

### image_url and get_image

`image_url` builds a picture's address. `get_image` fetches its bytes. See [Images](#images).

```ruby
client.image_url("<file>.jpg") # => "https://api.oushodh.dev/v1/images/<file>.jpg"
client.get_image("<file>.jpg") # => the picture's bytes
```

## Models

`Meta`, `Page`, `SearchResult`, `Medicine`, `MedicineDetail`, `Monograph` and `Prices` have a reader for each field
the API documents, with the API's own names: `medicine.product_name`, `medicine.prices.strip&.amount`, `page.next`.
A value no source gives is `nil`. Times, such as `last_updated`, stay strings like `2026-11-09T15:27:34Z`. The
[medicine object](https://oushodh.dev/docs/medicine) page describes every field.

Each model keeps the whole JSON object, so fields the API adds later are kept too. Read them with `[]` or `dig`, or
get the hash with `to_h`:

```ruby
medicine["a_new_field"]
medicine.dig("prices", "currency")
medicine.to_h
```

## Paging

`list_medicines` gives one page: `items`, `next` and `total`. Pass `next` back as `cursor:` for the next page. `next`
is `nil` on the last page.

`medicines` does this for you, page after page to the end. With a block, it yields each medicine. Without one, it
returns an `Enumerator` that fetches each page only when it needs it:

```ruby
client.medicines(limit: 500) do |medicine|
  save(medicine)
end

first_ten = client.medicines(q: "napa").first(10) # fetches one page
```

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

`updated_since:` takes a string like `2026-11-08T09:30:00Z`, or a `Time` (or anything with `to_time`). The SDK sends
a `Time` in UTC to the whole second. It means "at or after", so the medicine that set the time comes back once more.
Store each medicine by its `uuid`: it never changes. Medicines are never deleted and IDs are never reused.

## Errors

Every error is an `Oushodh::Error`. It has `status` (the HTTP status), `code` (the API's error code) and `message`.
Match on `code` or on the class, never on `message`: the message is for people and may change. When an error answer
is not JSON, `code` is `nil` and `message` is `HTTP <status>`.

| Class                            | Status | `code`                             | Retried             |
| -------------------------------- | ------ | ---------------------------------- | ------------------- |
| `Oushodh::BadRequestError`       | 400    | `bad_request`                      | no                  |
| `Oushodh::AuthenticationError`   | 401    | `unauthorized`                     | no                  |
| `Oushodh::PermissionDeniedError` | 403    | `plan_expired` or `plan_limit`     | no                  |
| `Oushodh::NotFoundError`         | 404    | `not_found`                        | no                  |
| `Oushodh::RateLimitError`        | 429    | `rate_limited` or `quota_exceeded` | `rate_limited` only |
| `Oushodh::InternalServerError`   | 5xx    | `internal`                         | yes                 |
| `Oushodh::ConnectionError`       | none   | none: the network failed           | yes                 |
| `Oushodh::TimeoutError`          | none   | none: the request timed out        | yes                 |

`TimeoutError` is a kind of `ConnectionError`. `RateLimitError#retry_after` holds the `Retry-After` seconds.

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

## Retries and rate limits

Every route is a `GET`, so the SDK can safely try again. It retries up to `max_retries` times (default 2):

- `429 rate_limited`: it waits the seconds in the `Retry-After` header, then tries again.
- `5xx` and network errors: it waits a little longer each time, with jitter.
- Any other `4xx`: it never retries. They give the same answer every time.

Your plan sets how many requests each key may make in a minute (60 a minute on Developer). Over that limit, the API
answers `429 rate_limited` with a `Retry-After` header.

Your plan also sets how many requests your account may make in a month. When they are used up, the API answers
`429 quota_exceeded` until the next month. The SDK raises it at once and never waits. Its `retry_after` holds the
seconds to the next month.

```ruby
begin
  client.meta
rescue Oushodh::RateLimitError => e
  raise unless e.code == "quota_exceeded"

  warn "Monthly quota used up. It resets in #{e.retry_after.to_i} seconds."
end
```

## Plan limits

Some plans read only the first medicines, in the order of their permanent number. Lists and search leave out the rest.
A lookup by ID of such a medicine raises `Oushodh::PermissionDeniedError` with `code` `plan_limit`. An expired plan
gives `code` `plan_expired`. `client.meta.medicines` says how many medicines your key reads.

## Images

`product_image` is the address of a medicine's picture. When it is under `/v1/images/`, Oushodh keeps the copy and
serves it with no key, so an `<img>` tag can show it. The file never changes, so it can be cached for a year.

`image_url(file)` builds that address. `get_image(file)` fetches the bytes and sends no key. Both take the file name,
not the whole address, and escape it.

```ruby
url = medicine.product_image

if url&.start_with?(client.image_url(""))
  jpeg = client.get_image(url.split("/").last)
  File.binwrite("#{medicine.uuid}.jpg", jpeg)
end
```

Any other address belongs to the source, and it can move or be removed.

## Develop

```sh
bundle install
bundle exec rake # RuboCop, then the tests
```

The tests use a local WEBrick server and fake keys. They never call the API.

| Path                    | What it holds                                           |
| ----------------------- | ------------------------------------------------------- |
| `lib/oushodh.rb`        | Loads the whole SDK: `require "oushodh"`.               |
| `lib/oushodh/client.rb` | `Oushodh::Client`, one method per route.                |
| `lib/oushodh/models/`   | One file per model, all built on `Oushodh::Model`.      |
| `lib/oushodh/errors/`   | One file per error class, all under `Oushodh::Error`.   |
| `lib/oushodh/http/`     | The transport, the `Response` type and the retry rules. |

## Release

For maintainers.

1. Set `Oushodh::VERSION` in `lib/oushodh/version.rb` and date the version in `CHANGELOG.md`.
2. Merge to `main`, then push a tag `v<version>`, such as `v0.1.0`.
3. The Release workflow checks that the tag matches the version, runs the tests and publishes to RubyGems with
   trusted publishing. No secret is stored.

## Links

- API docs: [oushodh.dev/docs](https://oushodh.dev/docs)
- API keys: [app.oushodh.dev](https://app.oushodh.dev)
- Changes: [CHANGELOG.md](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).

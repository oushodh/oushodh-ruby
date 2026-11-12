# Changelog

## 0.1.0 (unreleased)

- First version of the Ruby SDK for the Oushodh API `/v1`.
- `Oushodh::Client`: `meta`, `list_medicines`, `medicines` (an `Enumerator` that pages to the end), `search`,
  `get_medicine`, `image_url` and `get_image`.
- Models for `Medicine`, `MedicineDetail`, `Monograph`, `Page`, `SearchResult` and `Meta`, with a reader per field.
  Unknown fields are kept.
- Errors by family under `Oushodh::Error`, each with `status`, `code` and `message`.
- Retries on `429 rate_limited` (honours `Retry-After`), `5xx` and network errors. `429 quota_exceeded` is raised at
  once.
- No runtime dependencies.

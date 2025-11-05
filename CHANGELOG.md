## 0.2.0

**Breaking Changes:**
- Renamed `SimplefinAccountSet.errors` to `SimplefinAccountSet.serverMessages` for clarity.

**New Features:**
- Added `filterByOrganizationId()` extension method to `SimplefinAccountSet` for client-side organization filtering.
- CLI now includes server messages in all output formats (text/markdown, JSON, CSV).

**Improvements:**
- Server messages are properly integrated into CLI output instead of being written to stderr.
- Updated documentation with examples of handling server messages.

## 0.1.0

- Initial SimpleFIN Bridge client implementation.

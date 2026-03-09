# Changes to Original sip_ua

Tracks all modifications relative to the upstream `sip_ua` package.

## App-side fixes (not in the fork itself)

- **Originator enum jsonEncode crash** — Added `.toString()` to `callState.originator` before passing it into maps that get `jsonEncode`d. The `Originator` enum has no `toJson()`, so the raw enum value crashed `jsonEncode`. Fixed in `call_session_manager.dart` (3 sites) and `sip_call_repository.dart` (1 site).

# SMS LLM Fallback Extraction — Design Spec

**Date:** 2026-07-10
**Scope:** Extend existing LLM SMS-parsing fallback to also populate `category` and `account` (previously only `merchant`/`amount`/`type`).

---

## Context

`SmsProvider.processRawSms` already falls back to `SmsParserAdapter` (Gemma on-device LLM) when `SmsParser.parse` (regex tiers) returns null. That fallback currently extracts `merchant`, `amount`, `type` only. `category` (via `SmsRulesEngine`, merchant-keyword lookup) and `account` (via sender-ID hint / regex `accountHint`) stay purely deterministic even when the LLM already had to be invoked — so an unrecognized bank/merchant on an unparseable SMS leaves the pending card with no category and no account, requiring full manual entry.

This spec extends the fallback so that when regex fails, the LLM also contributes category and account guesses, cutting manual entry to a confirm-tap in more cases.

**Gate:** LLM involvement (all four fields) fires ONLY when `SmsParser.parse()` returns null. Regex success continues to short-circuit — no LLM call, no behavior change for already-working formats.

---

## Changes

### 1. `SmsParserAdapter` (`lib/ai/sms_parser_adapter.dart`)

- `SmsParseResult` gains `final String? account`.
- `parse()` gains `List<String> availableAccounts = const []`.
- Prompt: when `availableAccounts` is non-empty, appends the list and instructs the model to reply with the exact matching name or `null`.
- Validation: returned `account` must be an exact (case-sensitive) member of `availableAccounts`; otherwise `null`. Same defensive pattern as `CategorizationAdapter.suggest`'s category-membership check — never trust free-form LLM output as an ID.

```
<start_of_turn>user
Extract transaction from this SMS as JSON.
SMS: "..."
Accounts: HDFC Savings, ICICI Credit Card, Cash
If the SMS matches one of these accounts, set "account" to its exact name, else null.
Reply with only: {"merchant":"...","amount":0.0,"type":"debit|credit","account":"..."}
Unknown fields use null.
<end_of_turn>
<start_of_turn>model
```

### 2. `SmsProvider.processRawSms` (`lib/providers/sms_provider.dart`)

- Track `regexFailed = parsed == null` before the existing AI-merchant-fallback block.
- Pass `_accounts.accounts.map((a) => a.displayName).toList()` as `availableAccounts` to `SmsParserAdapter.parse`.
- AI-picked `account` flows into the synthesized `ParsedSmsResult.accountHint`. No change needed to `_resolveAccount` — it does a `displayName.toLowerCase().contains(hint.toLowerCase())` check, and an exact name trivially contains itself. Ambiguity (multiple accounts whose names overlap) still resolves to "leave blank" per existing rule.
- After the existing `SmsRulesEngine.categorize(parsed?.merchant)` lookup: if it missed (`categoryId == null`) AND `regexFailed` AND `parsed?.merchant != null` AND `aiInfer != null`, call:
  ```dart
  CategorizationAdapter.suggest(
    merchant: parsed!.merchant!,
    availableCategories: _prefs.activeCategories.isNotEmpty
        ? _prefs.activeCategories
        : Category.categories.map((c) => c.id).toList(),
    infer: aiInfer,
  )
  ```
  Same category-id-list convention `add_expense_sheet.dart` already uses for manual entry. Result is already validated against the id list by `CategorizationAdapter` — used directly as `categoryId`, no `_resolveCategoryId` fuzzy pass needed.
- Import `CategorizationAdapter` (currently only `InferFn` is imported from that file).

### 3. Untouched

- `SmsParser` (regex tiers) — no changes, still the first-tried, zero-cost path.
- `SmsRulesEngine` — still tried first for category; LLM is a fallback on top, not a replacement.
- `PendingSmsTransaction`, `SmsPendingCard` — no schema or UI changes; `categoryId`/`accountHint` were already nullable, optional fields.

---

## Error Handling

Same guarantees as the existing adapters — AI is enhancement-only, never blocking:

| Scenario | Behaviour |
|---|---|
| `aiInfer` not provided (AI disabled/not ready) | Fallback skipped entirely, same as today. |
| LLM returns account not in `availableAccounts` | `account` field is `null`; user picks manually. |
| LLM returns unparseable JSON / throws | Whole `SmsParserAdapter.parse` returns `null` (existing behavior, unchanged). |
| `CategorizationAdapter.suggest` returns invalid/no category | `categoryId` stays `null`; category chip row shown unselected (existing unparsed/no-category UI, unchanged). |

---

## Testing

- Extend `test/ai/sms_parser_adapter_test.dart`:
  - Account name present in `availableAccounts` and returned by LLM → populated on result.
  - Account name returned by LLM but not in `availableAccounts` → `null` (guards hallucination).
  - No `availableAccounts` passed → `account` is `null` regardless of LLM output.
- No new provider-level integration test — `sms_provider.dart` has no existing test file, and SMS AI-fallback is tested at the adapter unit level throughout this codebase (`sms_parser_adapter_test.dart`, `categorization_adapter_test.dart`). Consistent with that convention.

---

## Out of Scope

- Changing how `SmsRulesEngine` or regex-tier `accountHint` work — deterministic paths unchanged.
- New UI for showing "AI-suggested" badges on SMS pending cards (categorization's manual-entry flow does this via pulse animation; not extended to SMS cards here).
- Provider-level integration test harness for `sms_provider.dart` (no existing precedent in this repo; flagged as future work if desired).

# AI Provider Setup

This guide explains how AI provider configuration should be handled during the Firebase-first rollout.

## Current Phase Limits

During Phase 1 and Phase 2, AI work is documentation and planning only.

Do not enable unrestricted production AI calls until a pilot is approved.

---

## Supported Provider Direction

The platform should remain provider independent.

Potential providers:

- Anthropic Claude
- OpenAI
- Google Gemini
- Azure OpenAI
- Other compatible providers

The application should eventually route AI requests through a provider abstraction so customers can choose the AI provider they are comfortable with.

---

## Owner-Operator Mode

In owner-operator mode, the driver or small business may provide its own AI provider account and pay its own usage.

Recommended limits:

- One provider at launch
- Explicit monthly spend limit
- API key stored securely
- Usage reviewed weekly during pilot

If the key is entered on-device, it must be stored securely and never written to Firestore or logs.

---

## Fleet-Managed Mode

In fleet mode, the fleet administrator should manage AI centrally.

Recommended approach:

- AI keys stored only in Firebase Functions secrets or Google Cloud Secret Manager
- Drivers never see the provider key
- Tenant-level usage limits
- Per-driver usage logging
- Fleet administrator billing visibility

---

## Backend Secret Storage

Do not store AI provider keys in:

- Swift source files
- Xcode project files
- Firestore documents readable by clients
- Firebase Storage
- GitHub repositories
- Plaintext logs

Recommended storage:

- Firebase Functions secrets
- Google Cloud Secret Manager
- CI/CD secrets for deployment only

---

## Phase 2 Recommendation

For Phase 2, document provider setup only.

Do not add production AI backend functions until:

- Firebase rules are tested
- App Check monitoring is validated
- Budget alerts are active
- Owner-operator pilot is approved
- AI usage limits are approved

---

## Future AI Abstraction

Recommended future interface:

```swift
protocol AIProvider {
    func send(_ request: AIRequest) async throws -> AIResponse
}
```

Future provider implementations may include:

```text
AnthropicProvider
OpenAIProvider
GeminiProvider
AzureOpenAIProvider
```

Business logic should call the abstraction, not a vendor-specific client.

# iTruckers Co-Driver

AI-powered trucking companion for independent owner-operators and fleet-managed trucking operations.

**iTruckers Co-Driver** is a voice-first trucking assistant designed for iPhone, iPad, and macOS. It helps drivers and dispatchers manage AI-assisted communications, hours-of-service workflows, routing context, maintenance reporting, compliance records, and fleet operations.

This repository is being organized around a **Firebase-first production architecture** so the platform can support Apple clients today and future Android or web clients later.

---

## Product Modes

### Owner-Operator Mode

For independent drivers who want to run the app under their own accounts.

The owner-operator is responsible for:

- Firebase project setup
- AI provider account setup
- API usage costs
- Billing alerts
- Production credentials
- Driver profile and app configuration

### Fleet-Managed Mode

For trucking companies, dispatch teams, and fleet administrators.

The fleet administrator is responsible for:

- Central Firebase project setup
- Driver account management
- Fleet data organization
- Shared AI provider configuration
- Production billing
- Security rules
- Monitoring and operational support

Drivers should not need to manage API keys in a fleet-managed deployment unless the fleet intentionally enables per-driver AI credentials.

---

## Recommended Production Stack

- **Client apps:** SwiftUI for iOS, iPadOS, and macOS
- **Primary backend:** Firebase
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **File storage:** Firebase Storage
- **Server logic:** Cloud Functions for Firebase
- **Push notifications:** Firebase Cloud Messaging
- **AI providers:** Anthropic, OpenAI, Google Gemini, Azure OpenAI, or another supported provider
- **Secret storage:** Firebase Functions secrets / Google Cloud Secret Manager

---

## Documentation

Start here:

- [Firebase Setup](docs/Firebase_Setup.md)
- [AI Provider Setup](docs/AI_Provider_Setup.md)
- [Owner-Operator Onboarding](docs/Owner_Operator_Onboarding.md)
- [Fleet Administrator Onboarding](docs/Fleet_Administrator_Onboarding.md)
- [Security Guide](docs/Security_Guide.md)
- [Production Checklist](docs/Production_Checklist.md)
- [Troubleshooting](docs/Troubleshooting.md)

---

## Architecture Direction

The production architecture should be Firebase-first.

CloudKit or local Apple-only sync may still exist in parts of the current Apple implementation, but production documentation and future deployment planning should assume Firebase as the long-term backend of record.

This makes the platform easier to extend to:

- Android
- Web dashboards
- Fleet administration portals
- Server-side automation
- Centralized billing
- Multi-tenant customer deployments
- Third-party integrations

---

## AI Provider Strategy

The application should remain AI-provider independent.

Customers should be able to use the AI service they are most comfortable with, including:

- Anthropic Claude
- OpenAI
- Google Gemini
- Azure OpenAI
- Future compatible providers

The recommended architecture is to route all model calls through an application-level AI provider abstraction instead of coupling business logic directly to a single vendor.

---

## Security Principles

Production deployments should follow these principles:

- Do not ship private API keys in client apps.
- Use Firebase Authentication for user identity.
- Use Firestore rules to enforce tenant, fleet, and driver boundaries.
- Store provider secrets in backend-only secret storage.
- Use App Check to reduce abuse from unauthorized clients.
- Use billing alerts and usage monitoring for Firebase and AI providers.
- Rotate keys immediately if exposed.

See [Security Guide](docs/Security_Guide.md) for details.

---

## Production Readiness

Before launch, complete the [Production Checklist](docs/Production_Checklist.md).

At minimum, verify:

- Firebase billing is enabled.
- Authentication providers are configured.
- Firestore rules are locked down.
- Storage rules are locked down.
- App Check is configured and enforced after testing.
- AI credentials are backend-only.
- Budget alerts are configured.
- Owner-operator and fleet onboarding flows are tested.

---

## Status

This project is under active development and production hardening.

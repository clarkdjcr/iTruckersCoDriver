# Security Guide

This guide defines the security expectations for the Firebase-first iTruckers Co-Driver rollout.

## Phase 1 and Phase 2 Security Goals

- Deny unsafe access by default.
- Require Firebase Authentication for shared data.
- Enforce tenant boundaries.
- Keep provider secrets out of client code.
- Use App Check monitoring before enforcement.
- Configure budget alerts before production use.

---

## Authentication

Use Firebase Authentication for all production users.

Recommended sign-in methods:

- Email/password for controlled testing
- Sign in with Apple for Apple-first deployments
- Enterprise SSO for fleet customers when required

Each authenticated user should have a membership record under the tenant they belong to.

```text
tenants/{tenantId}/members/{uid}
```

---

## Tenant Isolation

All shared production records should be scoped under a tenant.

```text
tenants/{tenantId}/...
```

Rules must prevent users from reading or writing across tenants.

---

## Role-Based Access

Recommended roles:

```text
owner
admin
dispatcher
driver
maintenance
viewer
```

Do not rely on client-side role checks alone. Firestore and Storage rules must enforce access server-side.

---

## Firestore Rules

The baseline `firestore.rules` file denies unmatched reads and writes.

Before production, test at minimum:

- Unauthenticated user denied.
- Unrelated authenticated user denied.
- Tenant member allowed only within own tenant.
- Admin-only actions denied to drivers.
- Driver cannot access another tenant.

---

## Storage Rules

The baseline `storage.rules` file requires tenant membership and denies unmatched paths.

Before production, test:

- Unauthenticated upload denied.
- Cross-tenant download denied.
- Tenant member upload allowed only under tenant path.
- Delete restricted to tenant admin.

---

## AI Provider Secrets

Provider API keys must not be committed to the repository or shipped in client code.

Recommended secret locations:

- Firebase Functions secrets
- Google Cloud Secret Manager
- CI/CD deployment secrets

Avoid storing secrets in:

- Firestore documents readable by clients
- Firebase Storage
- Swift source files
- Xcode project files
- Plaintext logs

---

## App Check

Roll out App Check in stages:

1. Configure providers.
2. Monitor traffic.
3. Resolve rejected legitimate clients.
4. Enforce App Check only after validation.

Do not enforce App Check before test clients are confirmed to pass checks.

---

## Logging

Logs must not include:

- API keys
- Authentication tokens
- Full health data
- Sensitive driver identity documents
- Payment information

Log operational events, not secrets.

---

## Incident Response

If a key or sensitive credential is exposed:

1. Revoke the exposed key.
2. Create a replacement key.
3. Update backend secret storage.
4. Redeploy affected services.
5. Review usage logs.
6. Review repository history.
7. Document the incident and corrective action.

---

## Phase 2 Security Exit Criteria

- Firestore rules deployed to staging.
- Storage rules deployed to staging.
- Emulator tests or manual rule tests completed.
- App Check monitoring enabled.
- Budget alerts configured.
- AI secrets not present in repository.

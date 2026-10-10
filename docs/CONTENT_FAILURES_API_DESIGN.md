# Content Failures API design

Status: Proposed for review

This document defines the first API design for a production-style content-failure management service. It is an API design proposal only; it does not authorize implementation.

## Purpose

The service records and coordinates content failures reported by company teams. A content failure is an operational issue affecting the correctness, availability, or delivery of company content.

The API should allow authorized users to create a failure, assign ownership, track its lifecycle, record investigation activity, attach evidence, and preserve an audit trail.

Each content failure must also capture the technical characterization of the failure: whether it is deterministic, its observed probability, reproduction guidance, the affected IP/content category, the first test program where it was observed, and the specific failing pattern.

## Proposed boundaries

The first version contains these resource types:

- `content-failures`: the primary operational record;
- `comments`: human discussion attached to a failure;
- `timeline-events`: immutable workflow and system history;
- `attachments`: metadata for evidence stored in object storage; and
- `users` or `teams`: referenced identities, managed by the company's identity system rather than by this API.

Every content failure has an owning team. Examples include `SCAN`, `ARRAY`, and `RESET`. The owning team is responsible for triage, investigation, and resolution unless the failure is reassigned through an authorized workflow. The owning team is distinct from `content_categories`, which describes the affected IP or content area such as `Core`, `UPI`, or `PCIE`.

The API should not initially become a general content-management system, notification platform, or full project-management tool.

## Enterprise access boundary

This is an internal enterprise API. It must not be reachable through a public API endpoint or public network path.

The preferred AWS boundary is a private API Gateway REST API reachable through an interface VPC endpoint for `execute-api`. A resource policy should restrict invocation to approved VPC endpoint identifiers and AWS principals. Private DNS should be used so approved clients resolve the internal API name without using a public endpoint.

Requests still require identity authentication and authorization. Network placement is an additional control, not a replacement for user or service authorization.

The initial access model should include:

- private subnets or approved corporate network connectivity for clients;
- security groups and route controls around the interface VPC endpoint;
- an enterprise identity provider through Cognito federation or an approved OIDC/SAML integration;
- short-lived user or workload tokens;
- role and team claims checked by the API;
- CloudTrail and API access logging;
- VPC endpoint and API resource policies denying unapproved principals; and
- separate endpoint, credentials, state, and data for staging and production.

The exact client connectivity pattern—VPN, Direct Connect, Transit Gateway, or another corporate network path—must be documented before implementation.

## Confirmed platform choices

- API protocol: private API Gateway REST API;
- user authentication: OIDC through the approved enterprise identity provider;
- application logging: CloudWatch Logs with structured records and environment-specific retention;
- evidence storage: private, versioned S3 bucket using short-lived pre-signed upload URLs;
- notifications: Amazon SNS topics for authorized content-failure notifications;
- infrastructure and application delivery: a simple GitHub Actions workflow using GitHub OIDC and short-lived AWS role credentials.

SNS is part of v1 for notification delivery. It is separate from test-observation ingestion: observations use the direct API-to-Lambda-to-DynamoDB path initially. Notification topics, subscriptions, filtering, and failure handling require environment-specific configuration.

### DynamoDB access constraint

DynamoDB does not provide password-based database access. The API and deployment workflows must use IAM authorization with temporary role credentials. No DynamoDB password should be created, stored, or passed through the API.

The Lambda execution role should receive only the actions and table or index resources required by the API. GitHub Actions should assume separate staging and production deployment roles through GitHub OIDC, with production access restricted by repository, branch, environment, and approval conditions.

## Initial delivery workflow

The first CI workflow should remain intentionally small:

1. Pull request: format, validate, test, scan for secrets, and generate a read-only Terraform plan.
2. Merge to the staging branch or approved staging environment: assume the staging deployment role through GitHub OIDC and deploy only after review.
3. Production deployment: require a protected GitHub environment and explicit approval, then assume a separate production role and apply the reviewed plan.

CI must not contain long-lived AWS access keys. Production and staging must use separate GitHub environment variables, role trust conditions, Terraform state, and AWS resources.

## Proposed lifecycle

```text
OPEN → INVESTIGATING → MITIGATED → RESOLVED
  └──────────────→ CLOSED
```

Suggested meanings:

- `OPEN`: reported and awaiting investigation;
- `INVESTIGATING`: an owner is actively examining the failure;
- `MITIGATED`: impact has been reduced, but the underlying cause may remain;
- `RESOLVED`: the failure is fixed and verification is complete; and
- `CLOSED`: the record is complete and no more operational work is expected.

Transitions should be validated server-side. Every transition should create an immutable timeline event containing the actor, timestamp, previous state, new state, and optional reason.

## Proposed API version

Base path:

```text
/v1
```

### Content failures

```text
POST   /v1/content-failures
GET    /v1/content-failures
GET    /v1/content-failures/{failure_id}
PATCH  /v1/content-failures/{failure_id}
POST   /v1/content-failures/{failure_id}/transitions
```

The list endpoint should support pagination and filtering by status, severity, service, owner, team, and time range. It should use cursor pagination rather than unbounded result sets.

### Comments and history

```text
GET    /v1/content-failures/{failure_id}/comments
POST   /v1/content-failures/{failure_id}/comments
GET    /v1/content-failures/{failure_id}/timeline
```

Comments may be editable only under an explicitly defined policy. Timeline events are append-only and cannot be edited through the API.

### Attachments

```text
POST   /v1/content-failures/{failure_id}/attachments
POST   /v1/content-failures/{failure_id}/attachments/{attachment_id}/complete
GET    /v1/content-failures/{failure_id}/attachments
DELETE /v1/content-failures/{failure_id}/attachments/{attachment_id}
```

The API should return a pre-signed upload URL rather than proxying file bytes through Lambda. Attachment completion should validate that the expected object exists and record its metadata.

## Proposed content-failure representation

```json
{
  "failure_id": "cf_01J...",
  "title": "Product descriptions missing after publication",
  "summary": "Newly published items are missing descriptions in the public API.",
  "failure_characterization": {
    "deterministic": true,
    "failure_probability": {
      "value": 1.0,
      "unit": "occurrence_rate",
      "observation_count": 10,
      "failure_count": 10,
      "observation_window": "test-run"
    },
    "reproduction_steps": [
      "Publish an item with the affected content profile.",
      "Request the item from the public API.",
      "Compare the description field with the source record."
    ],
    "reproduction_available": true,
    "content_categories": ["Core"],
    "first_observed_test_program": "content-publish-regression-v4",
    "failing_pattern": "Description is absent in the API response while publication reports success."
  },
  "status": "INVESTIGATING",
  "severity": "HIGH",
  "service": "content-publishing",
  "environment": "production",
  "reported_by": {
    "user_id": "user_123",
    "display_name": "Example User"
  },
  "owner": {
    "user_id": "user_456",
    "display_name": "Example Owner"
  },
  "owning_team": "SCAN",
  "impact": {
    "customer_visible": true,
    "affected_region": "global",
    "started_at": "2026-10-10T14:00:00Z"
  },
  "created_at": "2026-10-10T14:15:00Z",
  "updated_at": "2026-10-10T14:30:00Z",
  "resolved_at": null,
  "closed_at": null,
  "version": 3
}
```

### Failure-characterization fields

`deterministic`

Whether the failure is expected to occur consistently when the same relevant conditions are reproduced. This is a classification, not a replacement for observed evidence.

`failure_probability`

An observed rate derived from a defined number of attempts in a defined observation window. The API should store the numerator, denominator, unit, and observation window rather than only a percentage. A probability without this context is not reviewable.

`reproduction_steps`

An ordered list of steps, commands, inputs, or conditions needed to reproduce the failure. It may be empty when reproduction is not currently known.

`reproduction_available`

Whether the current evidence is sufficient for another engineer to attempt reproduction. This is separate from whether reproduction has actually succeeded.

`content_categories`

One or more IP or content categories associated with the failure. Initial examples include `Power Management`, `Mesh`, `Core`, `UPI`, and `PCIE`. The API should use controlled values, while allowing a failure to affect multiple categories.

`first_observed_test_program`

The first test program, suite, or campaign in which the failure was observed. This should reference a stable identifier where one exists, with a human-readable name optionally stored for display.

`failing_pattern`

A concise description of the specific recurring failure signature, such as an error sequence, mismatch, timeout, assertion, or affected input pattern. This should remain distinct from the general summary.

The exact identifier format, severity values, ownership model, impact fields, probability units, test-program identity model, and category taxonomy remain subject to review.

`owning_team`

The controlled team identifier accountable for this content failure. It must reference an approved team registry value and must not be accepted as an authorization bypass. The API must verify that the caller may create or modify failures for the selected team.

## Write and concurrency behavior

- `POST` operations that create a resource should accept an idempotency key.
- Mutating requests should use optimistic concurrency, such as an `If-Match` value or resource version.
- A stale update should return `409 Conflict` or `412 Precondition Failed`, according to the final contract.
- Server-managed fields such as identifiers, timestamps, status history, and audit fields must not be client-controlled.
- PATCH semantics must be explicitly defined; omitted fields should remain unchanged.

## Authentication and authorization proposal

Authentication should use the company's identity provider through Amazon Cognito or an existing OIDC integration. The API should receive a verified user identity and claims; it should not trust user IDs supplied only in request bodies.

Initial authorization roles:

- `viewer`: read failures and permitted history;
- `responder`: create failures, comment, upload evidence, and update assigned work;
- `incident_manager`: assign ownership, change severity, and perform lifecycle transitions; and
- `administrator`: manage configuration and exceptional recovery actions.

Authorization must enforce owning-team boundaries. A caller may be able to view failures across teams while only creating, assigning, or transitioning failures for teams granted by their identity claims. The final model depends on whether this API serves one company, multiple business units, or multiple external tenants.

## Error format

All errors should use one documented shape:

```json
{
  "error": {
    "code": "CONTENT_FAILURE_NOT_FOUND",
    "message": "Content failure was not found.",
    "request_id": "req_01J...",
    "details": []
  }
}
```

Error messages should be safe to expose to callers. Internal stack traces, credentials, tokens, and sensitive data must remain in protected logs only.

## Operational requirements

- Every request receives a correlation or request identifier.
- Logs use structured JSON and exclude secrets and unnecessary personal data.
- Mutations emit audit and domain events.
- Asynchronous consumers must be retry-safe and use a dead-letter queue.
- List endpoints must have bounded page sizes and predictable sort order.
- Production and staging use separate API stages, data, configuration, and Terraform state.
- Data retention, attachment limits, notification behavior, and recovery objectives require explicit decisions before implementation.

## Decisions needed before the API contract is finalized

1. Is the service single-company only, or must it support multiple tenants or business units?
2. Which identity provider should authenticate users?
3. What severity values and response-time expectations does the company use?
4. Which lifecycle transitions are allowed for each role?
5. Should a failure represent one event, or may it group repeated occurrences?
6. Are comments editable or append-only?
7. What file types, size limits, retention, and malware-scanning requirements apply to attachments?
8. Which notifications are required, and through which approved channels?
9. What information is sensitive and must be redacted from logs or responses?
10. What are the staging and production recovery-point and recovery-time objectives?


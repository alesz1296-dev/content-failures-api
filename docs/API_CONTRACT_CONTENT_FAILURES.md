# Content Failures API contract

Status: Proposed for review  
Version: `v1`  
Base path: `/v1`

This contract defines the HTTP interface for recording and managing content failures. It is environment-neutral; staging and production expose the same contract through separate deployments and data stores.

## Common behavior

All requests use HTTPS and JSON unless otherwise stated.

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>
X-Request-Id: <optional-client-id>
```

The service returns an `X-Request-Id` header on every response. If the caller does not provide one, the service generates it.

Timestamps use ISO 8601 UTC strings. Identifiers are opaque strings and must be treated as case-sensitive.

## v1 method index

### Content failures

```http
POST   /v1/content-failures
GET    /v1/content-failures
GET    /v1/content-failures/{failure_id}
PATCH  /v1/content-failures/{failure_id}
POST   /v1/content-failures/{failure_id}/transitions
```

### Validation history

```http
GET  /v1/content-failures/{failure_id}/validation
POST /v1/content-failures/{failure_id}/validation
```

### Test observations

```http
GET  /v1/content-failures/{failure_id}/observations
POST /v1/content-failures/{failure_id}/observations
```

### Assignments and ownership history

```http
GET  /v1/content-failures/{failure_id}/assignments
POST /v1/content-failures/{failure_id}/assignments
```

### Engineering findings

```http
GET  /v1/content-failures/{failure_id}/findings
POST /v1/content-failures/{failure_id}/findings
```

### Remediation and verification

```http
GET  /v1/content-failures/{failure_id}/remediations
POST /v1/content-failures/{failure_id}/remediations
POST /v1/content-failures/{failure_id}/remediations/{remediation_id}/verify
```

### Comments and timeline

```http
GET  /v1/content-failures/{failure_id}/comments
POST /v1/content-failures/{failure_id}/comments
GET  /v1/content-failures/{failure_id}/timeline
```

### Attachments

```http
GET    /v1/content-failures/{failure_id}/attachments
POST   /v1/content-failures/{failure_id}/attachments
POST   /v1/content-failures/{failure_id}/attachments/{attachment_id}/complete
DELETE /v1/content-failures/{failure_id}/attachments/{attachment_id}
```

### Relationships

```http
GET    /v1/content-failures/{failure_id}/relationships
POST   /v1/content-failures/{failure_id}/relationships
DELETE /v1/content-failures/{failure_id}/relationships/{relationship_id}
```

## Enumerations

### Status

```text
OPEN
INVESTIGATING
MITIGATED
RESOLVED
CLOSED
```

### Severity

The initial contract reserves these values; the final company severity policy must define their meaning and response expectations.

```text
CRITICAL
HIGH
MEDIUM
LOW
```

### Content categories

Categories are controlled values. Initial values are:

```text
Power Management
Mesh
Core
UPI
PCIE
```

The category registry may grow without changing the API version. Clients must tolerate unknown future values.

### Validation status

```text
UNVALIDATED
CONFIRMED
REJECTED
NOT_REPRODUCED
NEEDS_MORE_DATA
```

## Content failure object

```json
{
  "failure_id": "cf_01JABC123",
  "title": "Product descriptions missing after publication",
  "summary": "Newly published items are missing descriptions in the public API.",
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
  "content_type": "publication-record",
  "technical_owner": {
    "user_id": "user_789",
    "display_name": "Example Engineer"
  },
  "validation": {
    "status": "CONFIRMED",
    "validated_by": {
      "user_id": "user_321",
      "display_name": "Content Engineer"
    },
    "validated_at": "2026-10-10T14:25:00Z"
  },
  "failure_characterization": {
    "deterministic": true,
    "failure_probability": {
      "value": 1.0,
      "unit": "occurrence_rate",
      "failure_count": 10,
      "observation_count": 10,
      "observation_window": "test-run",
      "observed_from": "2026-10-10T14:00:00Z",
      "observed_to": "2026-10-10T14:30:00Z"
    },
    "reproduction_available": true,
    "reproduction_steps": [
      "Publish an item with the affected content profile.",
      "Request the item from the public API.",
      "Compare the description field with the source record."
    ],
    "content_categories": ["Core"],
    "first_observed_test_program": {
      "program_id": "test-program-123",
      "name": "content-publish-regression-v4"
    },
    "failing_pattern": "Description is absent in the API response while publication reports success."
  },
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

## Create a content failure

```http
POST /v1/content-failures
Idempotency-Key: <unique-key>
```

Required request fields:

```json
{
  "title": "Product descriptions missing after publication",
  "summary": "Newly published items are missing descriptions in the public API.",
  "severity": "HIGH",
  "service": "content-publishing",
  "environment": "production",
  "content_type": "publication-record",
  "owning_team": "SCAN",
  "failure_characterization": {
    "deterministic": true,
    "failure_probability": {
      "value": 1.0,
      "unit": "occurrence_rate",
      "failure_count": 10,
      "observation_count": 10,
      "observation_window": "test-run",
      "observed_from": "2026-10-10T14:00:00Z",
      "observed_to": "2026-10-10T14:30:00Z"
    },
    "reproduction_available": true,
    "reproduction_steps": [],
    "content_categories": ["Core"],
    "first_observed_test_program": {
      "program_id": "test-program-123",
      "name": "content-publish-regression-v4"
    },
    "failing_pattern": "Description is absent in the API response while publication reports success."
  }
}
```

The server assigns `failure_id`, `reported_by`, timestamps, initial status (`OPEN`), version, and audit fields. Clients must not provide those fields.

`content_type`, `owning_team`, and `failure_characterization` are required for a complete failure record. `validation` starts as `UNVALIDATED` unless the caller is authorized to submit an initial validation record.

Responses:

- `201 Created` with the complete content failure object;
- `400 Bad Request` for malformed or invalid fields;
- `401 Unauthorized` when authentication is missing or invalid;
- `403 Forbidden` when the caller lacks permission;
- `409 Conflict` when the idempotency key conflicts with a different request; and
- `422 Unprocessable Entity` when the request is syntactically valid but violates domain rules.

## Get one content failure

```http
GET /v1/content-failures/{failure_id}
```

Responses:

- `200 OK` with the content failure object;
- `401 Unauthorized`;
- `403 Forbidden`; and
- `404 Not Found` with error code `CONTENT_FAILURE_NOT_FOUND`.

## List content failures

```http
GET /v1/content-failures?status=OPEN&severity=HIGH&content_category=Core&owning_team=SCAN&limit=25&cursor=<cursor>
```

Supported filters:

- `status`
- `severity`
- `service`
- `environment`
- `owning_team`
- `content_category`
- `first_observed_test_program_id`
- `observed_from`
- `observed_to`

The launch filter options are:

- `status`
- `severity`
- `owning_team`
- `content_type`
- `content_category`
- `validation_status`
- `service`
- `technical_owner_user_id`
- `first_observed_test_program_id`
- `created_from` and `created_to`
- `observed_from` and `observed_to`

For v1, the strongest supported work-queue filters should be `status`, `owning_team`, `severity`, `content_type`, and `validation_status`. Category, owner, service, test-program, and date filters may begin as secondary filters until measured usage justifies additional DynamoDB indexes.

`limit` defaults to `25` and must not exceed `100`. Results use a stable, documented sort order, such as `created_at` descending followed by `failure_id` descending.

Response:

```json
{
  "items": [],
  "next_cursor": null,
  "count": 0
}
```

Responses:

- `200 OK`;
- `400 Bad Request` for invalid filters;
- `401 Unauthorized`; and
- `403 Forbidden`.

## Validation history

Validation is an append-only history of reproduction and engineering review. A validation attempt must never overwrite an earlier attempt.

```http
GET  /v1/content-failures/{failure_id}/validation
POST /v1/content-failures/{failure_id}/validation
```

Create request:

```json
{
  "status": "NOT_REPRODUCED",
  "notes": "The failure did not reproduce with the current content version.",
  "test_program": {
    "program_id": "test-program-123",
    "name": "content-publish-regression-v4"
  },
  "test_run_id": "run-456",
  "environment": "staging",
  "content_version": "content-build-789",
  "reproduction_steps_attempted": [
    "Publish an item with the affected content profile.",
    "Request the item from the public API."
  ],
  "evidence_attachment_ids": []
}
```

The server assigns `validated_by` from the authenticated content engineer identity and assigns `validated_at`. `NOT_REPRODUCED` means this attempt did not reproduce the failure; it does not close or resolve the content failure.

Responses:

- `201 Created` with the immutable validation record;
- `400 Bad Request`;
- `401 Unauthorized`;
- `403 Forbidden` when the caller is not authorized as a content engineer or approved validator; and
- `404 Not Found`.

## Test observations

```http
GET  /v1/content-failures/{failure_id}/observations
POST /v1/content-failures/{failure_id}/observations
```

Observations record repeated test results used to support failure-probability calculations. They include the test program, test run, target, content version, timestamp, result, failing pattern, and evidence references.

## Assignments and ownership history

```http
GET  /v1/content-failures/{failure_id}/assignments
POST /v1/content-failures/{failure_id}/assignments
```

An assignment records changes to `content_type`, `owning_team`, `technical_owner`, or validator responsibility. Assignment history is append-only and requires authorization for the affected owning team.

## Engineering findings

```http
GET  /v1/content-failures/{failure_id}/findings
POST /v1/content-failures/{failure_id}/findings
```

Findings capture suspected or confirmed root cause, triggering conditions, workarounds, confidence, author, and supporting evidence.

## Remediation and verification

```http
GET  /v1/content-failures/{failure_id}/remediations
POST /v1/content-failures/{failure_id}/remediations
POST /v1/content-failures/{failure_id}/remediations/{remediation_id}/verify
```

A failure should not transition to `RESOLVED` until remediation has been verified or an authorized exception is recorded.

## Relationships

```http
GET    /v1/content-failures/{failure_id}/relationships
POST   /v1/content-failures/{failure_id}/relationships
DELETE /v1/content-failures/{failure_id}/relationships/{relationship_id}
```

Supported relationship types include `DUPLICATE_OF`, `RELATED_TO`, `CAUSED_BY`, `BLOCKED_BY`, and `REGRESSION_OF`.

## Update mutable fields

```http
PATCH /v1/content-failures/{failure_id}
If-Match: "3"
```

The request may update only fields permitted by the caller's role. Example:

```json
{
  "title": "Updated title",
  "owner_user_id": "user_789",
  "owning_team": "SCAN",
  "failure_characterization": {
    "reproduction_available": true,
    "reproduction_steps": ["Step one", "Step two"]
  }
}
```

Immutable or server-managed fields include `failure_id`, `reported_by`, `created_at`, `updated_at`, `version`, timeline events, and audit metadata.

Responses:

- `200 OK` with the updated object;
- `400 Bad Request`;
- `401 Unauthorized`;
- `403 Forbidden`;
- `404 Not Found`;
- `409 Conflict` for a domain conflict; and
- `412 Precondition Failed` when `If-Match` is stale or missing where required.

## Transition lifecycle state

```http
POST /v1/content-failures/{failure_id}/transitions
If-Match: "3"
```

Request:

```json
{
  "to_status": "MITIGATED",
  "reason": "Rolled back the affected publishing release."
}
```

The server validates the current status, caller role, and required fields. A successful transition creates an immutable timeline event.

Responses:

- `200 OK` with the updated content failure object;
- `400 Bad Request`;
- `403 Forbidden`;
- `404 Not Found`;
- `409 Conflict` for an invalid transition; and
- `412 Precondition Failed` for a stale version.

## Comments

```http
GET  /v1/content-failures/{failure_id}/comments
POST /v1/content-failures/{failure_id}/comments
```

Create request:

```json
{
  "body": "The failure reproduces only when the legacy content transformer is enabled."
}
```

Comments are append-only in this version. The API may support redaction later through an explicit administrator workflow.

Responses for creation:

- `201 Created`;
- `400 Bad Request`;
- `401 Unauthorized`;
- `403 Forbidden`; and
- `404 Not Found`.

## Timeline

```http
GET /v1/content-failures/{failure_id}/timeline
```

Timeline events are immutable and may include creation, updates, transitions, assignment changes, comments, attachment changes, and system events.

## Attachments

```http
GET  /v1/content-failures/{failure_id}/attachments
POST /v1/content-failures/{failure_id}/attachments
POST /v1/content-failures/{failure_id}/attachments/{attachment_id}/complete
DELETE /v1/content-failures/{failure_id}/attachments/{attachment_id}
```

Create-upload request:

```json
{
  "file_name": "failure-log.txt",
  "mime_type": "text/plain",
  "size_bytes": 24000,
  "sha256": "<hex-or-base64-digest>"
}
```

The response contains an attachment identifier and a short-lived pre-signed upload URL. The API does not proxy file bytes through Lambda. Completion verifies the object and records its final metadata.

Attachment size, content-type allowlist, retention, malware scanning, and deletion policy must be configured before production use.

## Error object

```json
{
  "error": {
    "code": "CONTENT_FAILURE_NOT_FOUND",
    "message": "Content failure was not found.",
    "request_id": "req_01JABC123",
    "details": []
  }
}
```

Error codes are stable identifiers for clients. Messages may change for clarity. Error responses must not expose stack traces, credentials, tokens, or sensitive internal data.

## Contract decisions still requiring confirmation

The current exercise decisions are:

1. The service supports one business unit. Multi-tenant support is deferred.
2. Use a simple conventional severity set for the exercise; response-time targets are out of scope.
3. Administrators may reassign ownership and change status at any time. A detailed role-by-transition matrix is deferred.
4. One content failure represents one event. Repeated occurrences are observations or related failures.
5. Comments are editable and appendable; edit history must remain auditable.
6. Attachments may include common images, CSV files, and document files. Exact MIME allowlist and size limits remain to be set before implementation.
7. Notifications use email and Slack. SNS can deliver email directly; Slack requires an approved HTTPS subscriber or a Lambda/webhook adapter.
8. No special sensitive-data classification is required for the exercise, but authenticated access still applies.
9. Staging and production RPO/RTO targets are deferred.

The following remain open:

1. Final severity values.
2. Whether `environment` is caller-supplied or derived from the deployment.
3. Whether probability is calculated by this API or supplied by a test system.
4. The authoritative registry and identifiers for test programs.
5. Attachment size, retention, and malware-scanning limits.
6. Identity provider choice and final role names.

## Preliminary supporting schemas

The following schemas are recorded as the preliminary v1 shape for review. Validation records, observations, and assignments are append-only. The current content-failure object may expose a summary of the active record, but the history resources remain authoritative for audit purposes.

### Validation record

```json
{
  "validation_id": "val_01JABC123",
  "failure_id": "cf_01JABC123",
  "status": "NOT_REPRODUCED",
  "validated_by": {
    "user_id": "user_321",
    "display_name": "Content Engineer"
  },
  "validated_at": "2026-10-10T15:00:00Z",
  "test_program": {
    "program_id": "test-program-123",
    "name": "content-publish-regression-v4"
  },
  "test_run_id": "run-456",
  "environment": "staging",
  "content_type": "publication-record",
  "content_version": "content-build-789",
  "target": {
    "target_id": "target-001",
    "target_type": "hardware-or-system",
    "configuration": "config-a"
  },
  "reproduction_steps_attempted": [
    "Publish an item with the affected content profile.",
    "Request the item from the API."
  ],
  "observed_behavior": "The expected missing description was not observed.",
  "notes": "Failure did not reproduce with the current content version.",
  "evidence_attachment_ids": ["att_01JABC123"],
  "created_at": "2026-10-10T15:00:00Z"
}
```

`NOT_REPRODUCED` records one unsuccessful reproduction attempt. It does not automatically resolve, close, or change the lifecycle status of the content failure.

### Test observation

```json
{
  "observation_id": "obs_01JABC123",
  "failure_id": "cf_01JABC123",
  "observed_at": "2026-10-10T14:30:00Z",
  "result": "FAILED",
  "test_program": {
    "program_id": "test-program-123",
    "name": "content-publish-regression-v4"
  },
  "test_run_id": "run-456",
  "environment": "production",
  "content_type": "publication-record",
  "content_version": "content-build-789",
  "content_categories": ["Core"],
  "owning_team": "SCAN",
  "target": {
    "target_id": "target-001",
    "target_type": "hardware-or-system",
    "configuration": "config-a"
  },
  "input_reference": "input-case-42",
  "failing_pattern": "Description is absent while publication reports success.",
  "error_signature": {
    "code": "CONTENT_FIELD_MISSING",
    "message": "Description field was not returned."
  },
  "reproduced": true,
  "evidence_attachment_ids": ["att_01JABC123"],
  "source": "automated-test-system",
  "created_at": "2026-10-10T14:31:00Z"
}
```

Observation results are `PASSED`, `FAILED`, `BLOCKED`, `SKIPPED`, or `ERROR`. The API should derive failure probability from eligible observations instead of allowing an unexplained percentage to be edited directly.

### Assignment record

```json
{
  "assignment_id": "asg_01JABC123",
  "failure_id": "cf_01JABC123",
  "content_type": "publication-record",
  "owning_team": "SCAN",
  "technical_owner": {
    "user_id": "user_789",
    "display_name": "Example Engineer"
  },
  "content_validator": {
    "user_id": "user_321",
    "display_name": "Content Engineer"
  },
  "assigned_by": {
    "user_id": "user_111",
    "display_name": "Incident Manager"
  },
  "reason": "Failure belongs to the SCAN content pipeline.",
  "effective_at": "2026-10-10T14:40:00Z",
  "created_at": "2026-10-10T14:40:00Z"
}
```

`owning_team`, `assigned_by`, `reason`, and `effective_at` are required. `technical_owner` and `content_validator` may be empty while work is unassigned.

### Current summary versus history

The main content-failure object should expose the active assignment and latest validation summary for convenient reads:

```json
{
  "content_type": "publication-record",
  "owning_team": "SCAN",
  "technical_owner": {
    "user_id": "user_789",
    "display_name": "Example Engineer"
  },
  "content_validator": {
    "user_id": "user_321",
    "display_name": "Content Engineer"
  },
  "validation": {
    "status": "CONFIRMED",
    "validated_by": {
      "user_id": "user_321",
      "display_name": "Content Engineer"
    },
    "validated_at": "2026-10-10T15:00:00Z"
  }
}
```

The complete assignment, validation, and observation histories remain available through their dedicated endpoints.


# Content Failures API security and access model

Status: Proposed for review  
Scope: staging and production

This document defines the preliminary security and access model for the private Content Failures API. It is a design artifact only and does not authorize implementation or deployment.

## Security objectives

The service must:

- remain unreachable from the public internet;
- authenticate every human and service caller;
- authorize actions using verified identity and team claims;
- isolate staging and production data and credentials;
- protect failure records, validation history, and evidence attachments;
- provide an audit trail for security- and workflow-sensitive actions;
- avoid long-lived credentials; and
- make access decisions reviewable and testable.

## Network access boundary

The API is a private API Gateway REST API.

```text
Corporate client or approved AWS workload
  -> VPN / Direct Connect / Transit Gateway
  -> interface VPC endpoint for execute-api
  -> private API Gateway REST API
  -> Lambda integration
```

The API Gateway resource policy should deny invocation unless the request arrives through an approved VPC endpoint and is made by an approved principal. Private DNS should resolve the internal API name for approved networks.

Network placement is an additional control. It does not replace authentication or authorization.

The final design must document the approved connectivity path, VPC endpoint IDs, endpoint security groups, route boundaries, and DNS behavior separately for staging and production.

## Identity model

### Human users

Human users authenticate through the enterprise identity provider using OIDC. The proposed AWS integration is:

```text
Enterprise OIDC provider
  -> Amazon Cognito federation
  -> signed user token
  -> API Gateway REST API authorizer
  -> Lambda authorization checks
```

Cognito federation is a preliminary choice because API Gateway can validate Cognito-issued JWTs while the enterprise provider remains the source of user identity. The provider, issuer, audience, scopes, and claim names must be confirmed before implementation.

### Automated test systems

Automated test systems are machine identities. They must not use human accounts or shared passwords.

The preferred options are:

- workload OIDC token exchanged for a short-lived AWS role session; or
- a dedicated service identity issuing a short-lived OIDC access token.

The chosen option must include a stable service identity, environment restriction, narrow permissions, rotation or expiry, and audit attribution.

### GitHub Actions

GitHub Actions assumes environment-specific AWS deployment roles through GitHub OIDC.

The role trust policy should restrict:

- GitHub organization;
- repository;
- workflow or reusable workflow identity;
- branch or tag;
- GitHub environment; and
- audience and issuer claims.

No long-lived AWS access keys may be stored in GitHub secrets.

## Proposed application roles

| Role | Intended permissions |
|---|---|
| `viewer` | Read failures, permitted validation history, observations, and attachments |
| `reporter` | Create failures, comments, observations, and evidence uploads |
| `content_engineer` | Submit validation records, findings, and reproduction results |
| `failure_owner` | Update and investigate failures owned by the caller's teams |
| `incident_manager` | Assign teams, assign owners, change severity, transition lifecycle state, and approve resolution |
| `administrator` | Manage exceptional operations, configuration, and access policy |

Roles are claims used by the application. AWS IAM roles control AWS resource access and are separate from these business roles.

## Proposed identity claims

The API should consume verified claims similar to:

```json
{
  "sub": "user-123",
  "email": "engineer@example.com",
  "name": "Example Engineer",
  "roles": ["content_engineer", "failure_owner"],
  "teams": ["SCAN", "RESET"],
  "environment": "production"
}
```

The API must derive `reported_by`, `validated_by`, `assigned_by`, and similar actor fields from verified claims. Clients must not be allowed to impersonate another user by submitting those fields.

## Team and ownership authorization

The following concepts are distinct:

- `content_type`: type of affected content;
- `content_categories`: affected IP or content areas such as `Core`, `UPI`, and `PCIE`;
- `owning_team`: accountable team such as `SCAN`, `ARRAY`, or `RESET`;
- `technical_owner`: current individual responsible for investigation; and
- `content_validator`: content engineer responsible for validation.

Authorization rules should include:

- a caller may create a failure only for an owning team they are authorized to report for;
- a `failure_owner` may update operational fields only for an authorized owning team;
- a `content_engineer` may create validation records only within their granted scope;
- an `incident_manager` may reassign ownership and change lifecycle state;
- a user may read across teams only if their role permits cross-team visibility; and
- every assignment, validation, and lifecycle change must record the authenticated actor.

The team registry and claim-to-team mapping must be authoritative and versioned. User-supplied team values are request data, not authorization evidence.

## API Gateway authorization

The private REST API should use:

- a resource policy restricted to approved VPC endpoint IDs and principals;
- a Cognito or equivalent JWT authorizer for human requests;
- throttling and request-size limits;
- access logging with request IDs;
- explicit method-level authorization requirements; and
- consistent denial responses that do not reveal protected resource existence unnecessarily.

The final choice between a Cognito authorizer and a Lambda authorizer depends on whether claims require custom validation beyond standard OIDC/JWT validation.

## Lambda execution permissions

Each Lambda function should use a separate execution role where practical. Roles must grant only the actions and resource ARNs required by that function.

Examples of separate responsibilities include:

- API handler: read and write approved DynamoDB records, create pre-signed S3 requests, and write logs;
- validation or observation worker: write observations and validation history;
- attachment worker: read object metadata, perform approved scanning or processing, and update attachment state; and
- reporting worker: read only the records required for derived metrics.

No Lambda function should receive unrestricted `dynamodb:*`, `s3:*`, or account-wide IAM permissions.

## DynamoDB protection

DynamoDB uses IAM authorization, not password-based database access.

- Lambda accesses tables through its execution role.
- GitHub Actions does not access application tables during normal CI.
- Administrative access uses separately controlled operator roles.
- Tables use encryption at rest and environment-specific keys or policies as required.
- Point-in-time recovery should be enabled for production.
- CloudTrail data events and application audit records should cover sensitive changes according to the retention policy.

## S3 evidence protection

Evidence buckets must:

- block all public access;
- require encryption;
- enable versioning;
- use environment-specific bucket names;
- deny insecure transport;
- restrict access through IAM and bucket policy;
- issue short-lived pre-signed URLs;
- validate object key ownership and content-failure association; and
- define file-size, content-type, retention, deletion, and malware-scanning rules.

The client must never choose an arbitrary bucket or object prefix. The API generates the object key and binds it to the failure and uploader identity.

## Audit and monitoring

Security-relevant actions must be attributable to an identity and request ID, including:

- authentication failures;
- authorization denials;
- failure creation and updates;
- assignment changes;
- validation submissions, including `NOT_REPRODUCED`;
- lifecycle transitions;
- attachment creation, completion, and deletion;
- administrative changes; and
- deployment role assumptions.

CloudWatch Logs should use structured JSON, redact tokens and secrets, and have separate retention settings for staging and production. CloudTrail records AWS API activity. Alarms should cover authorization-denial spikes, Lambda errors, throttling, queue depth, dead-letter messages, and unusual data access.

## Notification security

Amazon SNS is planned for v1 notification delivery. Topics must be separate for staging and production, and publishing must be limited to approved Lambda or EventBridge principals.

Notification payloads should contain only the minimum information required by subscribers. Sensitive failure evidence, tokens, credentials, and unrestricted attachment URLs must not be published to SNS. Pre-signed S3 URLs, if ever included, must be short-lived and purpose-specific.

Subscriptions must use approved endpoints and confirmation controls. Delivery failures, rejected subscriptions, and unauthorized publish attempts require CloudWatch monitoring and audit records.

## Environment isolation

Staging and production must have separate:

- AWS accounts or strongly isolated deployment roles;
- VPC endpoints and private DNS zones;
- API Gateway REST APIs and authorizer clients;
- Cognito app clients or identity configuration;
- Lambda functions and execution roles;
- DynamoDB tables;
- S3 evidence buckets;
- EventBridge buses and SQS queues;
- CloudWatch log groups and alarms;
- GitHub environments and deployment roles; and
- Terraform state buckets and lock files.

Production deployment requires a protected GitHub environment and explicit approval after review of the Terraform plan.

## Open decisions before implementation

1. Which enterprise OIDC provider will be used?
2. Will Cognito federation be accepted, or is a custom Lambda authorizer required?
3. What private connectivity path reaches the API from corporate users?
4. Which exact claims represent roles and teams?
5. Are staging and production in separate AWS accounts?
6. How will automated test systems authenticate and submit observations?
7. What evidence files require malware scanning?
8. What are the retention, recovery-point, and recovery-time requirements?
9. Which security events require alerts versus audit-only recording?


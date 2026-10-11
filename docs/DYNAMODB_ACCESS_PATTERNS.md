# DynamoDB access patterns and Terraform design

Status: Proposed for review  
Scope: staging and production

This document defines the preliminary DynamoDB design for the Content Failures API. It focuses on AWS implementation choices and Terraform boundaries. It does not authorize application or Terraform implementation.

## Design recommendation

Use two logical tables per environment:

1. `content-failures`: current failure records and bounded history such as validations, assignments, findings, remediations, comments, timeline events, and relationships.
2. `content-failure-observations`: individual test observations used for reproduction analysis and probability calculations.

This keeps the transactional failure workflow separate from potentially high-volume automated test ingestion. Both tables remain independently scalable and independently retained.

## Initial observation workload decision

The initial automated test workload is expected to be low and predictable:

- test programs run during scheduled night or weekend windows;
- a content failure ends the affected test run;
- observations are not continuously streamed;
- failure observations are not expected to arrive in sustained high-volume bursts; and
- test-run completion provides a natural operational boundary.

For the initial implementation, observation ingestion may use a direct synchronous path:

```text
Test system
  -> private API Gateway REST API
  -> Lambda
  -> content-failure-observations DynamoDB table
```

SQS buffering is not required for the first staging implementation. The design should still include throttling, idempotency, retry-safe writes, and alarms so that a future queue-backed ingestion path can be introduced without changing the observation schema.

This decision should be revisited if test programs begin running continuously, multiple programs overlap, test systems retry aggressively, or a single run produces a large burst of observations.

## Confirmed exercise decisions

- Observation retention: 90 days.
- Evidence retention: 90 days, subject to the final deletion and legal-hold policy.
- Customer-managed KMS keys: required in both staging and production.
- Staging and production: separate AWS accounts.
- DynamoDB Streams consumers: not selected yet; consumer, dead-letter, and replay requirements remain open.

### Observation ingestion replacement trigger

Replace the direct observation path with SQS buffering or batch ingestion when one or more of these conditions becomes true:

- test programs overlap substantially;
- peak writes begin causing throttling or elevated Lambda duration;
- retries produce duplicate or concurrent writes that need queue control;
- a test run produces a burst large enough to threaten API latency; or
- an external test system requires durable acceptance before processing.

The initial design does not require a numeric threshold. CloudWatch metrics should be used to establish a measured threshold after staging and early production-like testing.

Do not create a table for every history type. A single-table pattern for the failure aggregate keeps related records queryable by failure and allows transactional writes for state changes plus history events.

## `content-failures` table

### Primary key

```text
PK: FAILURE#<failure_id>
SK: META
```

The `META` item is the current content-failure record.

### History items

```text
PK: FAILURE#<failure_id>
SK: VALIDATION#<created_at>#<validation_id>

PK: FAILURE#<failure_id>
SK: ASSIGNMENT#<effective_at>#<assignment_id>

PK: FAILURE#<failure_id>
SK: FINDING#<created_at>#<finding_id>

PK: FAILURE#<failure_id>
SK: REMEDIATION#<created_at>#<remediation_id>

PK: FAILURE#<failure_id>
SK: COMMENT#<created_at>#<comment_id>

PK: FAILURE#<failure_id>
SK: TIMELINE#<created_at>#<event_id>

PK: FAILURE#<failure_id>
SK: RELATIONSHIP#<relationship_type>#<related_failure_id>

PK: FAILURE#<failure_id>
SK: ATTACHMENT#<created_at>#<attachment_id>
```

Identifiers and timestamps must provide a deterministic tie-breaker. The API must not rely on timestamp uniqueness.

## Proposed secondary indexes

Indexes should serve known API queries and team operations rather than provide arbitrary filtering.

### GSI1: team and status work queue

```text
GSI1PK: TEAM#<owning_team>#STATUS#<status>
GSI1SK: <updated_at>#<failure_id>
```

Supports:

- failures assigned to a team by lifecycle state;
- team investigation queues; and
- team dashboards ordered by recent activity.

### GSI2: content type and status

```text
GSI2PK: CONTENT_TYPE#<content_type>#STATUS#<status>
GSI2SK: <updated_at>#<failure_id>
```

Supports:

- failures by content type;
- unresolved failures for a content type; and
- content-type ownership review.

### GSI3: validation status and update time

```text
GSI3PK: VALIDATION#<validation_status>
GSI3SK: <updated_at>#<failure_id>
```

Supports:

- unvalidated failures;
- `NOT_REPRODUCED` follow-up queues;
- failures requiring more data; and
- validation operations reporting.

### Category and severity queries

Content categories and severity should initially be filter attributes within the supported team, content-type, or validation queries. Do not add separate indexes for every category or severity until observed access patterns justify them.

### Content-category index options

The available options are:

1. **No dedicated index initially** — query through team/content-type work queues and filter categories in the application. Lowest cost and simplest design, but unsuitable for large category-specific queues.
2. **Add category to an existing composite GSI** — for example, include category in a work-queue key when the real query is team plus category plus status. Efficient for a known query, but creates more key combinations.
3. **Dedicated category GSI** — use a category/status partition for direct category queues. Faster category queries, but adds index storage and write cost.
4. **Category projection or reporting table** — maintain a derived view for dashboards and analytics. Most flexible, but requires Streams or another projection process.

Recommendation for v1: choose option 1 unless category-only queues are a launch requirement. Revisit after observing real query frequency and item distribution.

## `content-failure-observations` table

### Primary key

```text
PK: FAILURE#<failure_id>
SK: OBSERVATION#<observed_at>#<observation_id>
```

Supports chronological observation history for one failure.

### GSI1: test run lookup

```text
GSI1PK: TEST_RUN#<test_run_id>
GSI1SK: <observed_at>#<observation_id>
```

Supports importing or reviewing all observations from a test run.

### GSI2: program and result lookup

```text
GSI2PK: PROGRAM#<program_id>#RESULT#<result>
GSI2SK: <observed_at>#<observation_id>
```

Supports program-level failure analysis and observation reporting.

### Observation retention

Observation retention must be decided separately from failure-record retention. If observations are retained with TTL, TTL must be treated as eventual cleanup rather than a precise deletion deadline. Evidence needed for audit or compliance must not rely on TTL alone.

## Required access patterns

The first implementation should explicitly support:

| Operation | Access pattern |
|---|---|
| Get failure | `PK=FAILURE#id`, `SK=META` |
| Get failure history | `PK=FAILURE#id`, `SK begins_with` history type |
| List team work queue | `GSI1PK=TEAM#team#STATUS#status` |
| List by content type | `GSI2PK=CONTENT_TYPE#type#STATUS#status` |
| List validation queue | `GSI3PK=VALIDATION#status` |
| Add validation | Transactional put under failure partition plus META update |
| Add assignment | Transactional put under failure partition plus META update |
| Transition status | Transactional META update plus timeline event |
| Add observation | Put into observation table; publish derived event if needed |
| Get test-run observations | `GSI1PK=TEST_RUN#run-id` |
| Get program failures | `GSI2PK=PROGRAM#program-id#RESULT#result` |

List APIs must use cursor pagination and bounded limits. They must not perform unbounded scans in production.

## Transaction and consistency rules

Use DynamoDB transactions when a command changes the current failure and its immutable history together, including:

- lifecycle transitions;
- assignment changes;
- validation summary updates;
- remediation verification; and
- attachment state changes.

Use optimistic concurrency on the `META` item with a numeric `version` attribute. The API must reject stale updates with `412 Precondition Failed` or the contract's final concurrency status.

Strongly consistent reads should be used only where the caller immediately needs confirmation of a just-committed workflow change. Eventual consistency is acceptable for list and reporting views unless the contract states otherwise.

## Streams and asynchronous workflows

Enable DynamoDB Streams on the `content-failures` table with `NEW_AND_OLD_IMAGES` if downstream consumers need before-and-after state. Streams may publish domain events for:

- failure created;
- status transitioned;
- assignment changed;
- validation recorded;
- remediation verified; and
- attachment state changed.

Consumers must be idempotent. Stream processing requires bounded retries and a dead-letter destination. Stream events must not become the only audit record; the immutable history items remain the system of record.

## Protection and recovery

Production tables should use:

- server-side encryption with an AWS KMS key where organizational policy requires customer-managed keys;
- point-in-time recovery;
- deletion protection where supported by the chosen Terraform provider behavior;
- CloudTrail data-event coverage appropriate to the security policy;
- least-privilege table and index permissions; and
- environment-specific backup and restore procedures.

Staging may use AWS-managed encryption and lower retention when that is acceptable, but it must preserve the security behaviors needed for integration testing.

## Terraform module boundaries

The Terraform design should separate reusable infrastructure modules from environment composition:

```text
infra/
  modules/
    content-failures-table/
    content-failure-observations-table/
    dynamodb-stream-processing/
    kms-data-key/
    cloudwatch-dynamodb/
  environments/
    staging/
    production/
```

The table modules should own:

- table definitions;
- primary keys and indexes;
- billing mode or capacity settings;
- point-in-time recovery;
- encryption;
- streams;
- TTL configuration where approved;
- tags; and
- table and index outputs.

The environment roots should own:

- table names and environment prefixes;
- KMS key selection;
- retention and capacity differences;
- stream consumers;
- alarms;
- IAM role composition; and
- deployment-specific dependencies.

No application code should construct table names independently of Terraform outputs or environment configuration.

## Cost and scaling posture

Begin with on-demand billing for staging and early production learning unless traffic is predictable enough to justify provisioned capacity. Review hot partitions before adding indexes. The initial scheduled observation workload does not require queue buffering or streaming infrastructure. Keep the ingestion boundary replaceable so SQS buffering or batch ingestion can be added if the workload changes.

## Open decisions

1. Which measured CloudWatch threshold should trigger replacement of direct observation ingestion?
2. Which list filters must be strongly supported at launch?
3. Should content categories receive a dedicated index after initial usage data?
4. Which consumers require DynamoDB Streams, and what are their dead-letter and replay requirements?


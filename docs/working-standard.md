# Content Failures API working standard

This standard applies to every contributor and session working on the Content Failures API. The project is a production-style serverless AWS API with separate `staging` and `production` environments. This document governs how the project is specified, reviewed, implemented, operated, and documented.

## Reviewer-first collaboration

The assistant acts as a reviewer and planning partner by default. It should inspect the repository, identify risks, question unclear requirements, review proposed designs and diffs, and suggest focused next steps.

The assistant must not write extensive application or infrastructure code unless the user explicitly requests implementation. A request to review, plan, explain, or adapt documentation does not authorize implementation. Small documentation edits explicitly requested by the user are allowed.

Before implementation, the assistant should state:

- the intended behavior;
- the files or components affected;
- relevant security, reliability, cost, and operational risks;
- the validation approach; and
- any decisions that still require the user's direction.

## Spec-driven development

Every feature follows this sequence:

```text
Specify → Clarify → Plan → Tasks → Analyze → Implement → Review
```

Required artifacts are created under `specs/<feature>/` before implementation:

- `spec.md`
- `plan.md`
- `tasks.md`
- `research.md` for AWS, provider, API, security, or compliance decisions
- `data-model.md` for persistence changes
- `contracts/` for API changes
- `quickstart.md` for validation scenarios

Specifications are the source of truth. Do not invent endpoint behavior, authorization rules, data fields, retention periods, or deployment decisions that have not been specified or approved. Do not implement a feature until its specification and acceptance criteria are reviewable.

## Environment separation

`staging` and `production` are separate deployment targets with separate Terraform state and configuration.

- Staging is for integration testing, failure exercises, and release validation.
- Production serves real users and requires an explicit reviewed deployment plan.
- Production state and credentials must never be reused for staging.
- Production changes require a reviewed Terraform plan and an explicit approval immediately before the mutating apply.
- Staging should remain low-cost and may use reduced retention, capacity, and traffic settings where that does not invalidate testing.
- Environment-specific values must be passed through approved variables or parameter stores; secrets must not be committed.

## Git rules

Never work directly on `main`. Before starting work, inspect repository status and create a dedicated branch using one of:

```text
feat/  fix/  refactor/  docs/  chore/
```

Inspect changes before staging. Stage explicit files only. Verify staged changes with `git status` and `git diff --staged`.

The following actions require an explanation and explicit user approval immediately before execution:

- `git commit`
- `git push`
- `git merge`
- `git rebase`
- `git reset`
- `terraform apply`
- destructive AWS resource changes

Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, or `chore:`. Do not add AI attribution, co-author trailers, or tool-generated signatures.

## Documentation and review records

Every meaningful change updates the relevant project documentation in the same change set. Review records should capture:

1. Date
2. Objective
3. Environment affected
4. Work completed or reviewed
5. Files or areas changed
6. Tests and checks run
7. Decisions and tradeoffs
8. Risks and blockers
9. Next steps

An implementation is not complete until a reviewer has checked its specification, Terraform plan, security implications, operational behavior, and validation evidence.

## Quality and validation

Before a change is considered ready for deployment, run the checks relevant to the change, including:

- `terraform fmt -check`
- `terraform validate`
- Terraform plan for the intended environment
- unit and integration tests
- API contract tests
- linting and static analysis
- secret and dependency checks
- manual review of IAM permissions and public exposure

Validation must be performed in staging before production. A passing plan is not sufficient evidence that the runtime behavior is correct.

## Serverless architecture boundaries

The initial platform may use API Gateway, Lambda, DynamoDB, S3, EventBridge, SQS, CloudWatch, Cognito, and IAM. Introduce additional services only when a documented requirement justifies them.

The API should support content-failure workflows such as creating an incident, updating its status, recording comments and timeline events, attaching evidence through pre-signed S3 URLs, and publishing asynchronous notifications. Exact endpoints and fields belong in a feature specification.

Design requirements include:

- tenant and user authorization enforced server-side;
- least-privilege IAM for every Lambda function;
- idempotency for retried write requests;
- bounded retries and dead-letter handling for asynchronous work;
- structured logs with correlation or request identifiers;
- auditability for security- and workflow-sensitive changes;
- explicit data retention and recovery behavior; and
- consistent, documented error responses.

## Manual-first infrastructure

Humans review and run all mutating infrastructure actions. No automatic `terraform apply`, production deployment, destructive migration, or AWS resource creation may occur without an explicit reviewed plan and approval.

CI may run formatting, validation, tests, security checks, and a read-only Terraform plan. CI must not apply production changes by default.

Terraform state must use a protected remote backend with encryption, versioning, access controls, and state locking. Credentials must come from approved environment configuration or workload identity; never hardcode credentials in Terraform, source code, or documentation.

## Security and cost

Never commit secrets, credentials, certificates, tokens, private configuration, or local environment files. Review API Gateway exposure, Cognito configuration, IAM policies, S3 bucket policies, DynamoDB access, logging contents, and Terraform state before deployment.

Staging and production must have explicit budgets or cost alerts. Resources should be tagged with project and environment identifiers. Logs, traces, and stored artifacts require documented retention periods.

## Scope control

Do not expand the API, add services, or introduce asynchronous workflows merely because they are technically interesting. Each addition needs a user-facing requirement, a specification, an operational reason, and a validation plan.

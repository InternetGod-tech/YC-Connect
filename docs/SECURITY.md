# Security notes (current build)
Implemented in code: role check on every engine action; record-level visibility (provider = own facility, worker = own requests, young person = own code, administrator = counts only); parameterised SQL everywhere; input length/format validation; idempotency key and open-duplicate check; transactional state changes with audit records; confirmation before destructive actions; no network access and no tokens or passwords stored.

Not implemented / outstanding: sign-in (role is chosen from a switcher, so the role checks are not an access boundary on a shared device); database encryption at rest; tamper-proof audit; remote sync; dependency scanning; external security review. Backups are plain files.
Production path: FastAPI + PostgreSQL behind OpenID Connect (PKCE), tokens in platform secure storage, same engine rules enforced server-side.

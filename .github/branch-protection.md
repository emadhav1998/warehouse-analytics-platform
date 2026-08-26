# Branch protection configuration

Apply these settings to both `main` and `develop` under **Settings > Branches**:

- Require a pull request before merging and at least one approving review.
- Dismiss stale approvals when new commits are pushed.
- Require conversation resolution and an up-to-date branch before merging.
- Require `dbt Build, Test, and Data Validation`.
- Require `Backend Lint and Tests`.
- Require `SQLFluff Lint`.
- Disallow force pushes and branch deletion.
- Apply the rule to administrators.

The workflow must run once before its status checks appear in GitHub's selector.

## Required Actions secrets

| Secret | Purpose |
|---|---|
| `DBT_SERVER` | SQL Server hostname reachable from GitHub-hosted runners |
| `DBT_DATABASE` | CI database name |
| `DBT_USER` | SQL-authenticated CI user |
| `DBT_PASSWORD` | CI user password |
| `WAREHOUSE_DB_CONNECTION_STRING` | ODBC connection string used by `validate_data.py` |

Use a dedicated, least-privileged CI database and user. GitHub does not expose
repository secrets to pull requests from forks, so those runs require approval
or a separate isolated database strategy.

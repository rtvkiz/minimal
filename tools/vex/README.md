# VEX — Vulnerability Exploitability eXchange

This directory documents **how** to add VEX statements to `minimal` images. The
statements themselves live in `vex/<image>.openvex.json`.

## What is VEX?

When a vulnerability scanner (grype, trivy, snyk) finds a CVE in our image, it's
reporting that a vulnerable *package* is present — not that the vulnerable
*code path* is reachable. VEX (Vulnerability Exploitability eXchange) is the
standardized way to tell a scanner "we know about CVE-X and it does **not**
affect this image, because we don't compile that subsystem / don't expose that
endpoint / patched it ourselves / etc."

We use [OpenVEX v0.2.0](https://openvex.dev/) — the format SPDX, CycloneDX, and
grype all consume natively. Every image in this repo has its own
`vex/<image>.openvex.json` document; build CI passes it to grype via `--vex`,
so the published dashboard shows both the **raw** CVE count and the
**effective** (VEX-adjusted) count.

## When to add a statement

Only when **all four** are true:

1. Grype reports a CVE against one of our images.
2. We have a defensible reason the CVE is not exploitable here.
3. The reason is durable (not "we'll fix it next week" — use a fix PR for that).
4. We can write the justification in one sentence a stranger would believe.

If we can't meet #4, don't write the statement. An unbacked `not_affected` is
worse than no statement at all.

## How to add a statement

1. Identify the image and the CVE: e.g. nginx, CVE-2024-12345.
2. Open `vex/nginx.openvex.json`.
3. Append to `statements[]`:

```json
{
  "vulnerability": { "name": "CVE-2024-12345" },
  "products": [
    { "@id": "pkg:oci/minimal-nginx?repository_url=ghcr.io/rtvkiz" }
  ],
  "status": "not_affected",
  "justification": "vulnerable_code_not_in_execute_path",
  "impact_statement": "The bug is in nginx's mail proxy module; we build with --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module."
}
```

4. Bump the document's top-level `version` integer (start at 1, increment on
   every edit — readers use this to detect changes).
5. Update the top-level `timestamp` to today (`date -u +%Y-%m-%dT%H:%M:%SZ`).
6. Run `tools/vex/validate.sh vex/nginx.openvex.json` locally to confirm shape.
7. Commit on a branch named `vex/<image>-<cve>`, open a PR. CI re-runs grype
   with `--vex`, so the dashboard count drops on merge.

## Valid `status` values

| Status | Meaning |
| --- | --- |
| `not_affected` | The CVE exists in the package but cannot affect this image. **Requires** `justification`. |
| `affected` | The CVE affects this image and we have not patched it. Should be rare — usually we'd ship a fix. |
| `fixed` | We backported a patch (in `melange.yaml`) and the vulnerable code is no longer present. |
| `under_investigation` | We're still triaging. Time-bound — don't leave a CVE in this state for weeks. |

## Standard `justification` values for `not_affected`

These are the OpenVEX-standardized strings — use them verbatim:

- `component_not_present` — the vulnerable component isn't in our image at all
- `vulnerable_code_not_present` — the package is present but our build excluded the vulnerable code
- `vulnerable_code_not_in_execute_path` — the code is present but unreachable in normal operation
- `vulnerable_code_cannot_be_controlled_by_adversary` — reachable but only via a trusted path
- `inline_mitigations_already_exist` — a runtime mitigation (e.g. seccomp, AppArmor) blocks exploitation

The free-form `impact_statement` field is where you explain *which* of these
applies and how, in one or two sentences.

## Validating locally

```bash
# all images
tools/vex/validate.sh

# specific file
tools/vex/validate.sh vex/nginx.openvex.json
```

CI runs `tools/vex/validate.sh` as a standalone job on every PR. A schema
failure blocks merge — same gate as the image build itself.

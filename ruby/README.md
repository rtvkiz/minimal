# minimal-ruby

Ruby 4.0.x runtime built from source.

## Curated default-gem set

To keep the CVE count at zero, the build replaces or removes a handful of gems that ship with stock Ruby 4.0.4. This matches the curation Chainguard applies to their `cgr.dev/chainguard/ruby` image.

| Gem | Stock Ruby 4.0.4 | minimal-ruby | Why |
|---|---|---|---|
| `json` | 2.18.0 | **2.19.5** | 2.18.0 has a HIGH CVE; bumped to the fixed release. |
| `net-imap` | 0.6.2 | **removed** | 5 CVEs and almost no Ruby app images need IMAP. Re-add with `gem install net-imap` if needed. |
| `bundler` | 4.0.10 | **removed** | Almost every app installs its own pinned bundler. Re-add with `gem install bundler`. |
| `rexml` | 3.4.4 | **removed** | Historical XML CVE risk. Re-add with `gem install rexml` if your code does `require "rexml/..."`. |

If you rely on any of the removed gems, install them in your Dockerfile:

```dockerfile
FROM ghcr.io/rtvkiz/minimal-ruby:latest
RUN gem install bundler net-imap rexml
```

Everything else in the default-gem set (irb, csv, json (the bumped one), uri, logger, etc.) ships unchanged.

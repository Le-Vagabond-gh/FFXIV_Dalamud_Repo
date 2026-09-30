#!/usr/bin/env bash
# Rebuilds repo.json from the latest GitHub release of every repo listed in plugins.txt.
# Each release must carry the plugin manifest (<InternalName>.json) and a *-full.zip asset;
# those are what Dalamud.NET.Sdk's plugin-release workflow publishes.
set -euo pipefail
cd "$(dirname "$0")/.."

entries=()
while read -r repo; do
  [[ -z "$repo" || "$repo" == \#* ]] && continue
  release=$(gh api "repos/$repo/releases/latest")
  zip_url=$(jq -r '.assets[] | select(.name | endswith("-full.zip")) | .browser_download_url' <<<"$release")
  manifest_url=$(jq -r '.assets[] | select(.name | endswith(".json")) | .browser_download_url' <<<"$release")
  if [[ -z "$zip_url" || -z "$manifest_url" ]]; then
    echo "::error::$repo: latest release is missing the manifest json or the -full.zip asset"
    exit 1
  fi
  manifest=$(curl -fsSL "$manifest_url")
  entries+=("$(jq \
    --arg zip "$zip_url" \
    --arg repo_url "https://github.com/$repo" \
    --argjson last_update "$(date -d "$(jq -r .published_at <<<"$release")" +%s)" \
    --argjson downloads "$(jq '[.assets[] | select(.name | endswith("-full.zip")) | .download_count] | add' <<<"$release")" \
    '. + {
      RepoUrl: (.RepoUrl // $repo_url),
      DownloadLinkInstall: $zip, DownloadLinkUpdate: $zip, DownloadLinkTesting: $zip,
      LastUpdate: $last_update, DownloadCount: $downloads,
      IsHide: false, IsTestingExclusive: false
    }' <<<"$manifest")")
done < plugins.txt

jq -s . <<<"${entries[*]}" > repo.json
echo "repo.json: $(jq length repo.json) plugins"

#!/bin/bash
set -euo pipefail

# 1. Run Gitleaks to generate a JSON report of leaks.
echo "Running Gitleaks..."
gitleaks detect --source=. --report-format=json --redact --exit-code=0 --report-path=/tmp/gitleaks-report.json
echo "Gitleaks report saved to /tmp/gitleaks-report.json."

# 2. Extract unique file paths flagged by Gitleaks.
echo "Extracting unique file paths from Gitleaks report..."
unique_files=$(jq -r '.[].File' /tmp/gitleaks-report.json | sort | uniq)

if [ -z "$unique_files" ]; then
  echo "No files found in Gitleaks report. Exiting."
  exit 0
fi

echo "Files to remove from history:"
echo "$unique_files"

# Pause and wait for a key press.
read -n 1 -r -p "Press any key to continue..." key
echo

# 3. Build arguments for git filter-repo.
filter_args=()
while IFS= read -r file; do
  filter_args+=(--path "$file")
done <<< "$unique_files"

# 4. Backup current remote URL (git-filter-repo removes remote metadata).
remote_url=$(git remote get-url origin)
echo "Current remote URL: $remote_url"

# 5. Run git filter-repo to remove the listed files from all commits.
echo "Running git filter-repo to remove files from history..."
git filter-repo "${filter_args[@]}" --invert-paths --force

# 6. Re-add remote origin.
echo "Re-adding remote origin..."
git remote add origin "$remote_url"

# Pause before pushing changes.
read -n 1 -r -p "Press any key to continue to push the changes..." key
echo

# 7. Force-push the new history (assumes master branch; adjust if necessary).
echo "Force pushing new history to remote..."
git push origin master --force

echo "Removing gitleaks report file..."
rm -vrf /tmp/gitleaks-report.json

echo "History rewrite complete."

#!/bin/bash

# When the repository labels are changed (i.e dropped a label, added a label, etc), you should make the same change to the lists below.
# For example, if the repository added a "type:task" type label, then add "-label:type:task" to the TYPE_LABELS_FILTER.
TYPE_LABELS_FILTER='-label:type:bug -label:type:feature -label:type:docs -label:type:refactor -label:type:help'

PRIORITY_LABELS_FILTER='label:priority-1-critical -label:priority-2-high -label:priority-3-medium -label:priority-4-low'

HAS_ISSUES_MISSING_LABELS=false

ISSUE_BODY="# Label check action\n"

for FILTER in "$STATUS_LABELS_FILTER" "$TYPE_LABELS_FILTER" "$PRIORITY_LABELS_FILTER"; do
  # Extract the label type from the filter
  LABEL_TYPE=$(echo "$FILTER" | cut -d ':' -f 2 | cut -d '-' -f 1)

  # Fetch issues filtered by the label type
  ISSUES_MISSING_LABEL=$(gh issue list --repo 'renovatebot/renovate' -s open -S "$FILTER" --json number) || { echo "Failed to fetch issues without $LABEL_TYPE labels"; exit 1; }

  if [ "$ISSUES_MISSING_LABEL" != "[]" ]; then
    HAS_ISSUES_MISSING_LABELS=true

    # Format the output to be a list of issue numbers
    FORMATTED_OUTPUT=$(echo "$ISSUES_MISSING_LABEL" | jq -r '.[].number' | sed 's/^/- #/')

    # Count the number of issues to determine if it's singular or plural
    ISSUE_COUNT=$(echo "$ISSUES_MISSING_LABEL" | jq '. | length')
    ISSUE_SINGULAR_PLURAL=$(if [ "$ISSUE_COUNT" -eq 1 ]; then echo "issue"; else echo "issues"; fi)

    # Append the list of issues to the new issue body
    ISSUE_BODY="$ISSUE_BODY## Found $ISSUE_COUNT $ISSUE_SINGULAR_PLURAL missing \`$LABEL_TYPE:\` labels:\n$FORMATTED_OUTPUT\n"
  fi
done

if [ "$HAS_ISSUES_MISSING_LABELS" ]; then
  LABEL_CHECK_ISSUE_EXISTS=$(gh search issues --repo 'renovatebot/renovate' --label 'action-label-check' --json number) || { echo "Failed to fetch existing label check issue"; exit 1; }

  ISSUE_NUMBER=$(echo "$LABEL_CHECK_ISSUE_EXISTS" | jq -r '.[0].number')

  if [ "$ISSUE_NUMBER" == "null" ]; then
    # Create a new issue with the list of issues
    gh issue create --repo 'renovatebot/renovate' --title "Label check action" --body "$(echo -e "$ISSUE_BODY")" || { echo "Failed to create issue"; exit 1; }
  else
    # Update the existing issue with the list of issues
    gh issue edit "$ISSUE_NUMBER" --repo 'renovatebot/renovate' --title "Label check action" --body "$(echo -e "$ISSUE_BODY")" || { echo "Failed to update issue"; exit 1; }

    # Reopen the issue
    gh issue reopen "$ISSUE_NUMBER" --repo 'renovatebot/renovate' || { echo "Failed to reopen issue"; exit 1; }
  fi

  # Provide an output in the action itself
  echo -e "$ISSUE_BODY"

  # Fail the action if there are issues missing the correct labels
  exit 1
fi

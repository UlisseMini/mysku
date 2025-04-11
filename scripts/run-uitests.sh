#!/bin/bash
# Removed strict mode to allow continuing after test failures
set -uo pipefail

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it (e.g., brew install jq)." >&2
    exit 1
fi

# Navigate to script's parent directory (project root)
cd "$(dirname "$0")/.."

# --- Configuration ---
SCHEME="mysku"
# Default destination (replace if needed or pass as argument)
DEST="platform=iOS,id=00008101-001434D40081401E" 
RESULT_BUNDLE="TestResults/latest.xcresult"
SCREENSHOT_DIR="TestResults/latest_screenshots"

rm -rf "$SCREENSHOT_DIR" "$RESULT_BUNDLE"

# --- Test Execution ---
echo "Running tests for scheme '$SCHEME'..."
mkdir -p TestResults # Ensure TestResults directory exists
xcodebuild test -scheme "$SCHEME" -destination "$DEST" -resultBundlePath "$RESULT_BUNDLE" 

# --- Screenshot Extraction ---
echo "Creating output directory: $SCREENSHOT_DIR"
mkdir -p "$SCREENSHOT_DIR"

echo "Extracting screenshot references from $RESULT_BUNDLE..."

# Get top-level JSON and extract the main test plan summary ID
TESTS_REF_ID=$(xcrun xcresulttool get --legacy --format json --path "$RESULT_BUNDLE" | \
                jq -r '.actions._values[0].actionResult.testsRef.id._value // empty')

if [ -z "$TESTS_REF_ID" ]; then
  echo "Error: Could not find testsRef ID in top-level JSON from $RESULT_BUNDLE." >&2
  exit 1
fi

# Get the JSON containing all test metadata (using TESTS_REF_ID)
# Then, extract the summaryRef IDs for each individual test run
SUMMARY_REF_IDS=$(xcrun xcresulttool get --legacy --format json --path "$RESULT_BUNDLE" --id "$TESTS_REF_ID" | \
                   jq -r '.. | objects | select(._type._name == "ActionTestMetadata") | .summaryRef.id._value // empty')

if [ -z "$SUMMARY_REF_IDS" ]; then
  echo "Warning: Found no individual test summary references (summaryRef IDs)." >&2
fi

# Loop through each test's summaryRef ID
echo "$SUMMARY_REF_IDS" | while IFS= read -r summary_id; do
  if [ -z "$summary_id" ]; then continue; fi
  # Get the specific test summary JSON
  JSON_SUMMARY=$(xcrun xcresulttool get --legacy --format json --path "$RESULT_BUNDLE" --id "$summary_id")

  # Extract Payload ID and Name for attachments from this summary
  # Output compact JSON objects, one per line
  echo "$JSON_SUMMARY" | jq -cr '
    .. | .attachments? | ._values[]? 
    | {payload_id: .payloadRef.id._value, name: .name._value}
  ' | while IFS= read -r item; do # Read each JSON object line
      payload_id=$(echo "$item" | jq -r '.payload_id // empty')
      attachment_name=$(echo "$item" | jq -r '.name // empty')

      if [ -n "$payload_id" ] && [ -n "$attachment_name" ]; then
        # Sanitize the name and add .png extension
        safe_fname=$(echo "$attachment_name" | tr -cd '[:alnum:][:space:]_-' | tr ' ' '_').png
        output_path="$SCREENSHOT_DIR/$safe_fname"
        xcrun xcresulttool export --legacy --path "$RESULT_BUNDLE" --id "$payload_id" --type file --output-path "$output_path"
      else
        echo "Skipping potentially invalid attachment data derived from: $item" >&2
      fi
    done
done

echo
echo "Successfully exported $(find "$SCREENSHOT_DIR" -type f | wc -l) screenshots to $SCREENSHOT_DIR"

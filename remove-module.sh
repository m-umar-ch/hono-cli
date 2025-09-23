#!/bin/bash

# Input validation
if [ -z "$1" ]; then
  echo "❌ Error: Please provide a module name"
  echo "Usage: $0 <module_name>"
  exit 1
fi

module_name=$1

# Validate module name (camelCase: starts with lowercase, then letters/numbers)
if [[ ! "$module_name" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
  echo "❌ Error: Module name must be in camelCase (start with lowercase letter, then letters/numbers only)"
  exit 1
fi

# Navigate to src/modules directory
if ! cd src/modules 2>/dev/null; then
  echo "❌ Directory src/modules does not exist"
  exit 1
fi

# Check if module exists
if [ ! -d "${module_name}" ]; then
  echo "❌ Error: Module ${module_name} does not exist"
  exit 1
fi

echo "🗑️  Removing module ${module_name}..."

# Remove the entire module directory
rm -rf "${module_name}"
echo "✅ Removed module directory: ${module_name}/"

# Update module.tags.ts
TAGS_FILE="module.tags.ts"
if [ -f "$TAGS_FILE" ]; then
  echo "🔧 Updating ${TAGS_FILE}..."

  # Remove the module tag line (handle both with and without trailing comma)
  sed -i "/${module_name}: \[\".*\"\],\?/d" "$TAGS_FILE"

  # Check if the moduleTags object is now empty and clean it up
  if ! grep -q ": \[" "$TAGS_FILE"; then
    # No modules left, create a clean empty object file
    cat >"$TAGS_FILE" <<EOF
export const moduleTags = {};
EOF
    echo "✅ Created clean empty ${TAGS_FILE}"
  else
    # Still has modules, clean up any formatting issues
    # Remove any extra closing braces or empty lines
    temp_file=$(mktemp)
    awk '
    BEGIN { in_object = 0; found_export = 0 }
    /export const moduleTags = \{/ { 
      print $0
      in_object = 1
      found_export = 1
      next
    }
    in_object && /^\};$/ && found_export {
      print $0
      exit
    }
    in_object && found_export && !/^[[:space:]]*$/ {
      print $0
    }
    ' "$TAGS_FILE" >"$temp_file"

    # Only replace if the temp file has content and looks valid
    if [ -s "$temp_file" ] && grep -q "export const moduleTags" "$temp_file"; then
      mv "$temp_file" "$TAGS_FILE"
    else
      rm -f "$temp_file"
    fi

    echo "✅ Cleaned up ${TAGS_FILE}"
  fi

  echo "✅ Removed ${module_name} tag from ${TAGS_FILE}"
fi

# Update src/index.ts
cd ../
INDEX_FILE="index.ts"

if [ -f "$INDEX_FILE" ]; then
  # Remove import statement
  sed -i "/import.*${module_name}Controller.*from.*\"\.\/modules\/${module_name}\/controller\"/d" "$INDEX_FILE"
  echo "✅ Removed import from ${INDEX_FILE}"

  # Remove controller from the controllers array
  # Handle different formatting styles
  if grep -q "const controllers: any = \[.*${module_name}Controller.*\];" "$INDEX_FILE"; then
    # Single line array - remove the controller from the array
    sed -i "s/, ${module_name}Controller//g; s/${module_name}Controller,//g; s/${module_name}Controller//g" "$INDEX_FILE"
  else
    # Multi-line array - remove the line containing the controller
    sed -i "/${module_name}Controller,\?/d" "$INDEX_FILE"
  fi

  # Check if controllers array is now empty and clean it up
  if grep -q "const controllers: any = \[\s*\];" "$INDEX_FILE"; then
    sed -i "s/const controllers: any = \[.*\];/const controllers: any = [];/" "$INDEX_FILE"
  elif grep -q "const controllers: any = \[" "$INDEX_FILE"; then
    # Multi-line empty array cleanup
    if ! grep -A 10 "const controllers: any = \[" "$INDEX_FILE" | grep -q "[a-zA-Z]Controller"; then
      # Replace multi-line empty array with single line
      sed -i '/const controllers: any = \[/,/^];$/c\const controllers: any = [];' "$INDEX_FILE"
    fi
  fi

  echo "✅ Removed ${module_name}Controller from controllers array"
fi

# Remove schema export from src/db/schema/index.ts
DB_SCHEMA_INDEX="db/schema/index.ts"
if [ -f "$DB_SCHEMA_INDEX" ]; then
  # Remove the export line for this module
  sed -i "/export \* from \"@\/modules\/${module_name}\/entity\";/d" "$DB_SCHEMA_INDEX"
  echo "✅ Removed schema export from ${DB_SCHEMA_INDEX}"
else
  echo "⚠️  Warning: ${DB_SCHEMA_INDEX} not found - skipping schema export removal"
fi

echo "✅ Module '${module_name}' successfully removed!"
echo "⚠️  Don't forget to run database migrations if this module contained entities that were deployed."

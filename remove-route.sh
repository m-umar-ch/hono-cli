#!/bin/bash

# Input validation
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Error: Please provide both module name and route name"
  echo "Usage: $0 <module_name> <route_name>"
  echo "Example: $0 user GET_PROFILE"
  exit 1
fi

module_name=$1
route_name=$2

# Validate module name (camelCase: starts with lowercase, then letters/numbers)
if [[ ! "$module_name" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
  echo "❌ Error: Module name must be in camelCase (start with lowercase letter, then letters/numbers only)"
  exit 1
fi

# Validate route name (uppercase letters, numbers, underscores)
if [[ ! "$route_name" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
  echo "❌ Error: Route name must be uppercase (e.g., GET, POST, DELETE, GET_ONE)"
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

# Convert route name to lowercase-hyphen format for file naming
route_file=$(echo "$route_name" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')

# Check if route exists
if [ ! -f "${module_name}/routes/${route_file}.${module_name}.route.ts" ]; then
  echo "❌ Error: Route ${route_name} does not exist in module ${module_name}"
  exit 1
fi

echo "🗑️  Removing route ${route_name} from module ${module_name}..."

# Remove the route file
rm "${module_name}/routes/${route_file}.${module_name}.route.ts"
echo "✅ Removed route file: ${module_name}/routes/${route_file}.${module_name}.route.ts"

# Update controller
cd "${module_name}/controller"
CONTROLLER_FILE="${module_name}.controller.ts"

if [ ! -f "$CONTROLLER_FILE" ]; then
  echo "❌ Error: Controller file not found: ${module_name}/controller/${module_name}.controller.ts"
  exit 1
fi

# Remove import statement
sed -i "/import.*${route_name}_Route.*${route_name}_Handler.*from.*\"..\/routes\/${route_file}\.${module_name}\.route\"/d" "$CONTROLLER_FILE"
echo "✅ Removed import from controller"

# Remove .openapi() call
# Find and remove the line containing the route's openapi call
sed -i "/\.openapi(${route_name}_Route, ${route_name}_Handler)/d" "$CONTROLLER_FILE"

# Fix semicolon on the last remaining .openapi() call
# Find the last .openapi() line and ensure it has a semicolon
LAST_OPENAPI_LINE=$(grep -n "\.openapi(" "$CONTROLLER_FILE" | tail -1 | cut -d: -f1)
if [ -n "$LAST_OPENAPI_LINE" ]; then
  # Add semicolon if it doesn't exist
  sed -i "${LAST_OPENAPI_LINE}s/[^;]$/&;/" "$CONTROLLER_FILE"
fi

echo "✅ Removed .openapi() call from controller"
echo "✅ Route '${route_name}' successfully removed from module '${module_name}'!"

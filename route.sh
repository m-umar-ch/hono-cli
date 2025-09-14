#! /bin/bash

# Input validation
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Error: Please provide both module name and route name"
  echo "Usage: $0 <module_name> <route_name>"
  echo "Example: $0 someModule PATCH"
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
  echo "💡 Create the module first using: ./module.sh ${module_name}"
  exit 1
fi

# Check if route already exists
if [ -f "${module_name}/routes/${route_name}.ts" ]; then
  echo "❌ Error: Route ${route_name} already exists in module ${module_name}"
  exit 1
fi

cd "${module_name}/routes"

# Determine HTTP method from route name
case "$route_name" in
  "GET_ONE"|"GET_PROFILE"|"GET_"*)
    method="get"
    ;;
  "POST_"*|"POST")
    method="post"
    ;;
  "PUT_"*|"PUT")
    method="put"
    ;;
  "PATCH_"*|"PATCH")
    method="patch"
    ;;
  "DELETE_"*|"DELETE")
    method="delete"
    ;;
  *)
    # Default case: try to extract method from route name, fallback to post
    if [[ "$route_name" == *"_"* ]]; then
      first_part=$(echo "$route_name" | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]')
      # Check if the first part is a valid HTTP method
      case "$first_part" in
        "get"|"post"|"put"|"patch"|"delete"|"head"|"options")
          method="$first_part"
          ;;
        *)
          method="post"  # Default to POST for unrecognized patterns
          ;;
      esac
    else
      # Single word routes default to post unless they match a known method
      method_lower=${route_name,,}
      case "$method_lower" in
        "get"|"post"|"put"|"patch"|"delete"|"head"|"options")
          method="$method_lower"
          ;;
        *)
          method="post"  # Default to POST for unrecognized single words
          ;;
      esac
    fi
    ;;
esac

# Create route file
cat >"${route_name}.ts" <<EOF
import { createRoute, RouteHandler } from "@hono/zod-openapi";
import { moduleTags } from "../../module.tags";
import { APISchema } from "@/lib/schemas/api-schemas";
import { HTTP } from "@/lib/http/status-codes";
import { HONO_RESPONSE } from "@/lib/utils";

export const ${route_name}_DTO = createRoute({
  path: "/${module_name}/${route_name}",
  method: "${method}",
  tags: moduleTags.${module_name},
  request: {},
  responses: {
    [HTTP.OK]: APISchema.OK,
  },
});

export const ${route_name}_Handler: RouteHandler<typeof ${route_name}_DTO> = async (c) => {
  return c.json(HONO_RESPONSE(), HTTP.OK);
};
EOF

echo "✅ Created route file: ${module_name}/routes/${route_name}.ts"

# Update controller index.ts
cd ../controller
CONTROLLER_FILE="index.ts"

if [ ! -f "$CONTROLLER_FILE" ]; then
  echo "❌ Error: Controller file not found: ${module_name}/controller/index.ts"
  exit 1
fi

# Add import statement after the last import from routes
IMPORT_LINE="import { ${route_name}_DTO, ${route_name}_Handler } from \"../routes/${route_name}\";"
LAST_ROUTES_IMPORT=$(grep -n "from \"../routes/" "$CONTROLLER_FILE" | tail -1 | cut -d: -f1)

if [ -n "$LAST_ROUTES_IMPORT" ]; then
  # Insert new import after the last routes import
  sed -i "${LAST_ROUTES_IMPORT}a\\${IMPORT_LINE}" "$CONTROLLER_FILE"
else
  # If no routes imports found, add after the last import
  LAST_IMPORT_LINE=$(grep -n "^import" "$CONTROLLER_FILE" | tail -1 | cut -d: -f1)
  sed -i "${LAST_IMPORT_LINE}a\\${IMPORT_LINE}" "$CONTROLLER_FILE"
fi

echo "✅ Added import to controller: ${module_name}/controller/index.ts"

# Add .openapi() call to the controller
# Find the last .openapi() line and handle semicolon properly
LAST_OPENAPI_LINE=$(grep -n "\.openapi(" "$CONTROLLER_FILE" | tail -1 | cut -d: -f1)

if [ -n "$LAST_OPENAPI_LINE" ]; then
  # Remove semicolon from the last .openapi() line if it exists
  sed -i "${LAST_OPENAPI_LINE}s/;$//" "$CONTROLLER_FILE"
  
  # Add new .openapi() call with semicolon
  sed -i "${LAST_OPENAPI_LINE}a\\  .openapi(${route_name}_DTO, ${route_name}_Handler);" "$CONTROLLER_FILE"
else
  echo "❌ Error: Could not find existing .openapi() calls in controller"
  exit 1
fi

echo "✅ Added .openapi() call to controller"
echo "✅ Route '${route_name}' successfully added to module '${module_name}'!"

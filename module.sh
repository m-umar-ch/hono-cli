#! /bin/bash

# Input validation
if [ -z "$1" ]; then
  echo "❌ Error: Please provide a module name"
  echo "Usage: $0 <module_name>"
  exit 1
fi

input=$1
resource_name=$input

# Validate resource name (camelCase: starts with lowercase, then letters/numbers)
if [[ ! "$resource_name" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
  echo "❌ Error: Module name must be in camelCase (start with lowercase letter, then letters/numbers only)"
  exit 1
fi

routes=("DELETE" "GET_ONE" "GET" "PATCH" "POST")

# Navigate to src/modules directory
if ! cd src/modules 2>/dev/null; then
  echo "❌ Directory src/modules does not exist"
  exit 1
fi

if [ -d "${resource_name}" ]; then
  echo "❌ Error: Module ${resource_name} already exists"
  exit 1
fi

# Create module directory structure with cleanup on failure
cleanup() {
  if [ -d "${resource_name}" ]; then
    echo "🧹 Cleaning up incomplete module directory..."
    rm -rf "${resource_name}"
  fi
}

trap cleanup EXIT

mkdir "$resource_name" || {
  echo "❌ Failed to create module directory"
  exit 1
}
cd "$resource_name" || {
  echo "❌ Failed to enter module directory"
  exit 1
}

mkdir controller service entity routes || {
  echo "❌ Failed to create subdirectories"
  exit 1
}

cd controller
touch index.ts
cat >>index.ts <<EOF
import { createRouter } from "@/lib/core/create-router";
EOF

for route in ${routes[@]}; do
  echo "import { ${route}_Route, ${route}_Handler } from \"../routes/${route}\";" >>index.ts
done

cat >>index.ts <<EOF

export const ${resource_name}Controller = createRouter()
EOF

# Add .openapi() calls with proper formatting
route_count=${#routes[@]}
for i in "${!routes[@]}"; do
  route="${routes[$i]}"
  if [ $i -eq $((route_count - 1)) ]; then
    # Last route gets semicolon
    echo "  .openapi(${route}_Route, ${route}_Handler);" >>index.ts
  else
    # Other routes without semicolon
    echo "  .openapi(${route}_Route, ${route}_Handler)" >>index.ts
  fi
done

cd ../entity
touch index.ts
cat >>index.ts <<EOF
import { index, serial } from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";
import type { InferSelectModel } from "drizzle-orm";
import { createTable } from "@/db/extras/db.utils";

export const ${resource_name} = createTable(
  "${resource_name}",
  {
    id: serial("id").primaryKey(),
  },
  (table) => [index().on(table.id)]
);

export const ${resource_name}Relations = relations(${resource_name}, ({ many, one }) => ({}));

export type ${resource_name^}TableType = InferSelectModel<typeof ${resource_name}>;

EOF

# Create service template
# cd ../service
# touch index.ts
# cat >>index.ts <<EOF
# import { db } from "@/db";
# import { eq } from "drizzle-orm";
# import { ${resource_name} } from "../entity";

# export class ${resource_name^}Service {
#   static async getAll() {
#     return await db.select().from(${resource_name});
#   }

#   static async getById(id: number) {
#     return await db.select().from(${resource_name}).where(eq(${resource_name}.id, id));
#   }

#   static async create(data: Omit<typeof ${resource_name}.\$inferInsert, 'id'>) {
#     return await db.insert(${resource_name}).values(data).returning();
#   }

#   static async update(id: number, data: Partial<typeof ${resource_name}.\$inferInsert>) {
#     return await db.update(${resource_name}).set(data).where(eq(${resource_name}.id, id)).returning();
#   }

#   static async delete(id: number) {
#     return await db.delete(${resource_name}).where(eq(${resource_name}.id, id)).returning();
#   }
# }
# EOF

cd ../routes

for route in ${routes[@]}; do
  touch "${route}.ts"

  case "$route" in
  "GET_ONE" | "GET_PROFILE" | "GET_"*)
    method="get"
    ;;
  "POST_"* | "POST")
    method="post"
    ;;
  "PUT_"* | "PUT")
    method="put"
    ;;
  "PATCH_"* | "PATCH")
    method="patch"
    ;;
  "DELETE_"* | "DELETE")
    method="delete"
    ;;
  *)
    # Default case: try to extract method from route name, fallback to post
    if [[ "$route" == *"_"* ]]; then
      first_part=$(echo "$route" | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]')
      # Check if the first part is a valid HTTP method
      case "$first_part" in
      "get" | "post" | "put" | "patch" | "delete" | "head" | "options")
        method="$first_part"
        ;;
      *)
        method="post" # Default to POST for unrecognized patterns
        ;;
      esac
    else
      # Single word routes default to post unless they match a known method
      method_lower=${route,,}
      case "$method_lower" in
      "get" | "post" | "put" | "patch" | "delete" | "head" | "options")
        method="$method_lower"
        ;;
      *)
        method="post" # Default to POST for unrecognized single words
        ;;
      esac
    fi
    ;;
  esac

  cat >>"${route}.ts" <<EOF
import { createRoute, RouteHandler } from "@hono/zod-openapi";
import { moduleTags } from "../../module.tags";
import { APISchema } from "@/lib/schemas/api-schemas";
import { HTTP } from "@/lib/http/status-codes";
import { HONO_RESPONSE } from "@/lib/utils";

export const ${route}_Route = createRoute({
  path: "/${resource_name}",
  method: "${method}",
  tags: moduleTags.${resource_name},
  request: {},
  responses: {
    [HTTP.OK]: APISchema.OK,
  },
});

export const ${route}_Handler: RouteHandler<typeof ${route}_Route> = async (c) => {
  return c.json(HONO_RESPONSE(), HTTP.OK);
};

EOF
done

# Create or update module tags file
cd ../../
TAGS_FILE="module.tags.ts"

if [ ! -f "$TAGS_FILE" ]; then
  # Create tags file if it doesn't exist
  cat >"$TAGS_FILE" <<EOF
export const moduleTags = {
  ${resource_name}: ["${resource_name^}"],
};
EOF
  echo "✅ Created ${TAGS_FILE} with ${resource_name} tag"
else
  # Add new tag to existing file
  # Check if the resource tag already exists
  if ! grep -q "${resource_name}:" "$TAGS_FILE"; then
    # Check if the moduleTags object is empty
    if grep -q "export const moduleTags = {};" "$TAGS_FILE"; then
      # Replace empty object with object containing the new module
      sed -i "s/export const moduleTags = {};/export const moduleTags = {\n  ${resource_name}: [\"${resource_name^}\"],\n};/" "$TAGS_FILE"
    else
      # Add new tag before the closing brace
      sed -i "/^};/i\\  ${resource_name}: [\"${resource_name^}\"]," "$TAGS_FILE"
    fi
    echo "✅ Added ${resource_name} tag to ${TAGS_FILE}"
  fi
fi

# Update src/index.ts with new controller
cd ../
INDEX_FILE="index.ts"

# Add import statement after the last import
IMPORT_LINE="import { ${resource_name}Controller } from \"./modules/${resource_name}/controller\";"
LAST_IMPORT_LINE=$(grep -n "^import" "$INDEX_FILE" | tail -1 | cut -d: -f1)
sed -i "${LAST_IMPORT_LINE}a\\
${IMPORT_LINE}" "$INDEX_FILE"

# Add controller to the controllers array
# Handle different formatting styles (multiline and single line arrays)
if grep -q "const controllers: any = \[\];" "$INDEX_FILE"; then
  # Empty array - replace with array containing the controller
  sed -i "s/const controllers: any = \[\];/const controllers: any = [\n  ${resource_name}Controller,\n];/" "$INDEX_FILE"
elif grep -q "const controllers: any = \[.*\];" "$INDEX_FILE"; then
  # Single line array (formatted by prettier) - add controller inside the brackets
  sed -i "s/const controllers: any = \[\([^]]*\)\];/const controllers: any = [\1, ${resource_name}Controller];/" "$INDEX_FILE"
else
  # Multi-line array - find the closing bracket and add before it
  CONTROLLERS_END_LINE=$(grep -n "^];" "$INDEX_FILE" | head -1 | cut -d: -f1)
  if [ -n "$CONTROLLERS_END_LINE" ]; then
    PREV_LINE=$((CONTROLLERS_END_LINE - 1))
    sed -i "${PREV_LINE}a\\
  ${resource_name}Controller," "$INDEX_FILE"
  fi
fi

# Update src/db/schema/index.ts with new entity export
DB_SCHEMA_INDEX="db/schema/index.ts"
if [ -f "$DB_SCHEMA_INDEX" ]; then
  SCHEMA_EXPORT_LINE="export * from \"@/modules/${resource_name}/entity\";"

  # Check if export already exists
  if ! grep -q "export \* from \"@/modules/${resource_name}/entity\"" "$DB_SCHEMA_INDEX"; then
    # Add export to the file
    echo "$SCHEMA_EXPORT_LINE" >>"$DB_SCHEMA_INDEX"
    echo "✅ Added schema export to ${DB_SCHEMA_INDEX}"
  fi
else
  echo "⚠️  Warning: ${DB_SCHEMA_INDEX} not found - skipping schema export"
fi

# Disable cleanup trap on successful completion
trap - EXIT
echo "✅ Module '${resource_name}' created successfully!"

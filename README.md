# @hono CLI Tool

A powerful command-line interface for managing Hono projects with TypeScript, providing scaffolding and automation for rapid API development.

## 🚀 Features

- **Project Initialization**: Quickly bootstrap new Hono projects from a proven starter template
- **Module Generation**: Create complete modules with controllers, entities, routes, and service templates
- **Route Management**: Add new routes to existing modules with proper OpenAPI integration
- **Automatic Setup**: Handles file permissions, imports, and project structure automatically

## 📦 Installation

### Quick Setup

1. **Clone this repository to your local scripts directory:**

   ```bash
   git clone <this-repo-url> ~/scripts/hono
   # git clone https://github.com/developer-256/hono-cli  ~/scripts/hono
   # or clone to any directory of your choice
   ```

2. **Add the @hono CLI to your PATH:**

   **For Zsh users (default on macOS and many Linux distros):**

   ```bash
   # run in terminal
   echo 'export PATH="$HOME/scripts/hono:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

   **For Bash users:**

   ```bash
   # run in terminal
   echo 'export PATH="$HOME/scripts/hono:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

   **If you cloned to a different directory, replace the path accordingly:**

   ```bash
   # For Zsh
   echo 'export PATH="/path/to/your/hono/directory:$PATH"' >> ~/.zshrc
   source ~/.zshrc

   # For Bash
   echo 'export PATH="/path/to/your/hono/directory:$PATH"' >> ~/.bashrc
   source ~/.bashrc

   # Or directly add this to your .zshrc or .bashrc file
   export PATH="/path/to/your/hono/directory:$PATH"
   ```

3. **Verify installation:**
   ```bash
   hono help
   ```

### Alternative: Create an Alias

If you prefer using an alias instead of adding to PATH:

```bash
echo 'alias hono="/path/to/your/hono/directory/hono"' >> ~/.zshrc
source ~/.zshrc
```

## 🛠️ Usage

### Initialize a New Project

Create a new Hono project from the starter template:

```bash
hono init my-awesome-api
```

This will:

- Create a new directory with your project name
- Clone the [Hono starter repository](https://github.com/developer-256/hono-starter)
- Set up the project structure properly (files directly in your project folder, not nested)
- Initialize a fresh git repository
- Provide next steps for setup

**Example:**

```bash
hono init my-blog-api
cd my-blog-api
bun i
cp .env.example .env
# Configure your .env file
npm run dev
```

### Add a New Module

Generate a complete module with all necessary files:

```bash
hono add module <module-name>
```

**Requirements:**

- Must be in camelCase (e.g., `user`, `blogPost`, `userProfile`)
- Must be run from the root of a Hono project

**What it creates:**

- `src/modules/<module-name>/`
  - `controller/index.ts` - OpenAPI controller with all HTTP methods
  - `entity/index.ts` - Drizzle ORM entity definition
  - `routes/` - Individual route files (GET.ts, POST.ts, DELETE.ts, PATCH.ts, GET_ONE.ts)
- Updates `src/modules/module.tags.ts` with new module tags
- Updates `src/index.ts` to register the new controller
- Updates `src/db/schema/index.ts` to export the new entity

**Example:**

```bash
hono add module user
hono add module blogPost
hono add module userProfile
```

### Add a New Route

Add a new route to an existing module:

```bash
hono add route <module-name> <route-name>
```

**Requirements:**

- Module must already exist
- Route name must be uppercase (e.g., `GET`, `POST`, `DELETE`, `GET_PROFILE`, `UPDATE_STATUS`)
- Must be run from the root of a Hono project

**What it does:**

- Creates a new route file in `src/modules/<module-name>/routes/<route-name>.ts`
- Updates the controller to include the new route
- Properly handles OpenAPI integration

**Examples:**

```bash
hono add route user GET_PROFILE
hono add route user UPDATE_PASSWORD
hono add route blogPost GET_BY_CATEGORY
hono add route userProfile DELETE_AVATAR
```

### Remove a Route

Remove a specific route from an existing module:

```bash
hono remove route <module-name> <route-name>
```

**Requirements:**

- Module and route must exist
- Route name must match exactly (case-sensitive)
- Must be run from the root of a Hono project

**What it does:**

- Removes the route file from `src/modules/<module-name>/routes/<route-name>.ts`
- Updates the controller to remove the route import and registration
- Maintains clean OpenAPI integration

**Examples:**

```bash
hono remove route user GET_PROFILE
hono remove route user UPDATE_PASSWORD
hono remove route blogPost GET_BY_CATEGORY
```

### Remove a Module

Remove an entire module and all its associated files:

```bash
hono remove module <module-name>
```

**Requirements:**

- Module must exist
- Must be run from the root of a Hono project

**What it does:**

- Removes the entire `src/modules/<module-name>/` directory
- Updates `src/modules/module.tags.ts` to remove module tags
- Updates `src/index.ts` to remove controller registration
- Updates `src/db/schema/index.ts` to remove entity export
- Cleans up all imports and references

**Examples:**

```bash
hono remove module user
hono remove module blogPost
hono remove module userProfile
```

**⚠️ Warning:** This action is irreversible. Make sure to backup your code before removing modules.

## 📁 Project Structure

After creating a project and modules, your structure will look like:

```
my-awesome-api/
├── src/
│   ├── modules/
│   │   ├── module.tags.ts
│   │   ├── user/
│   │   │   ├── controller/
│   │   │   │   └── index.ts
│   │   │   ├── entity/
│   │   │   │   └── index.ts
│   │   │   └── routes/
│   │   │       ├── GET.ts
│   │   │       ├── POST.ts
│   │   │       ├── DELETE.ts
│   │   │       ├── PATCH.ts
│   │   │       ├── GET_ONE.ts
│   │   │       └── GET_PROFILE.ts  # Custom route
│   │   └── blogPost/
│   │       └── ... (similar structure)
│   ├── index.ts
│   └── ... (other project files)
├── package.json
└── ... (other config files)
```

## 🎯 Best Practices

### Module Naming

- Use camelCase: `user`, `blogPost`, `orderHistory`
- Start with lowercase letter
- No spaces, hyphens, or special characters
- Be descriptive but concise

### Route Naming

- Use UPPERCASE with underscores: `GET`, `POST`, `GET_PROFILE`, `UPDATE_STATUS`
- Be descriptive about the action
- Follow RESTful conventions when possible

**HTTP Method Detection:**

The CLI automatically determines the HTTP method based on the route name:

- Routes starting with `GET_`, `POST_`, `PUT_`, `PATCH_`, `DELETE_` use the corresponding method
- Single word routes matching `GET`, `POST`, `PUT`, `PATCH`, `DELETE` use that method
- For unrecognized patterns, it defaults to `POST` method
- Examples:
  - `GET_PROFILE` → `get` method
  - `UPDATE_STATUS` → `post` method (UPDATE is not a valid HTTP method)
  - `SPECIAL` → `post` method (defaults to POST)
  - `DELETE_USER` → `delete` method

### Workflow Example

```bash
# 1. Create a new project
hono init my-ecommerce-api
cd my-ecommerce-api

# 2. Set up dependencies
bun i
cp .env.example .env
# Edit .env with your configuration

# 3. Create your modules
hono add module user
hono add module product
hono add module order

# 4. Add custom routes as needed
hono add route user GET_PROFILE
hono add route user UPDATE_PASSWORD
hono add route product SEARCH
hono add route order GET_BY_USER

# 5. Start development
npm run dev
```

## 🗑️ Uninstalling

### Complete Removal

To completely remove the @hono CLI from your computer:

1. **Remove the cloned directory:**

   ```bash
   rm -rf ~/scripts/hono
   # or rm -rf /path/to/your/hono/directory
   ```

2. **Remove PATH entry from shell configuration:**

   **For Zsh users:**

   ```bash
   # Remove the line containing hono from .zshrc
   sed -i '/export PATH.*hono.*PATH/d' ~/.zshrc
   source ~/.zshrc
   ```

   **For Bash users:**

   ```bash
   # Remove the line containing hono from .bashrc
   sed -i '/export PATH.*hono.*PATH/d' ~/.bashrc
   source ~/.bashrc
   ```

   **Alternative (Manual removal):**

   - Open `~/.zshrc` or `~/.bashrc` in your editor
   - Remove the line: `export PATH="$HOME/scripts/hono:$PATH"`
   - Save and run `source ~/.zshrc` or `source ~/.bashrc`

3. **Verify removal:**
   ```bash
   hono help  # Should return "command not found"
   echo $PATH | grep hono  # Should return nothing
   ```

### Remove Alias (if you used the alias method)

If you installed using an alias instead of PATH:

```bash
# For Zsh
sed -i '/alias hono=/d' ~/.zshrc
source ~/.zshrc

# For Bash
sed -i '/alias hono=/d' ~/.bashrc
source ~/.bashrc
```

## 🔧 Troubleshooting

### Command Not Found

If you get `command not found: hono`, check:

1. **Verify your shell and configuration file:**

   ```bash
   echo $SHELL  # Check your current shell
   ```

   - If using Zsh: edit `~/.zshrc`
   - If using Bash: edit `~/.bashrc`

2. **Check if the PATH was added correctly:**

   ```bash
   echo $PATH | grep hono  # Should show your hono directory
   ```

3. **Verify the export command was added to your shell config:**

   ```bash
   # For Zsh users
   grep "hono" ~/.zshrc

   # For Bash users
   grep "hono" ~/.bashrc
   ```

   The output should show: `export PATH="$HOME/scripts/hono:$PATH"`

4. **Source your configuration file:**

   ```bash
   # For Zsh
   source ~/.zshrc

   # For Bash
   source ~/.bashrc
   ```

5. **Check that the hono script exists and has execute permissions:**

   ```bash
   ls -la ~/scripts/hono/hono  # Verify file exists
   chmod +x ~/scripts/hono/hono  # Make it executable if needed
   ```

6. **Test with absolute path:**
   ```bash
   ~/scripts/hono/hono help  # Should work if PATH is the issue
   ```

### Permission Denied

If you get permission errors:

```bash
chmod +x /path/to/your/hono/directory/hono
chmod +x /path/to/your/hono/directory/module.sh
chmod +x /path/to/your/hono/directory/route.sh
```

### Not in a Hono Project

Make sure you're running `hono add` commands from the root of a Hono project (where package.json exists).

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📝 License

This tool is provided as-is for development convenience.

---

**Happy coding with Hono! 🔥**

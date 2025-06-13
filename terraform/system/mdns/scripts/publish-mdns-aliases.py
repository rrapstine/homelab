#!/usr/bin/env python3
import os
import sys # Good practice to import sys for exit codes if needed

# The executable path for mdns-publish-cname
mdns_publisher_executable = '/opt/venv/venv_mdns_publisher/bin/mdns-publish-cname' # Corrected from -sname to -cname based on your args list
aliases_file_path = '/home/richard/.mdns-aliases' # Or use os.path.expanduser('~/.mdns-aliases') for more portability

args = [mdns_publisher_executable] # Start with the command itself

try:
    with open(aliases_file_path, 'r') as f:
        for line in f: # Iterate line by line, more memory efficient than readlines() for large files
            stripped_line = line.strip() # Remove leading/trailing whitespace

            # Skip empty lines and lines starting with '#'
            if stripped_line and not stripped_line.startswith('#'):
                args.append(stripped_line)
except FileNotFoundError:
    print(f"Error: Aliases file not found at {aliases_file_path}", file=sys.stderr)
    sys.exit(1) # Exit with an error code if the file is not found
except Exception as e:
    print(f"Error reading or processing aliases file: {e}", file=sys.stderr)
    sys.exit(1) # Exit with an error code for other errors

# Only proceed if we actually found aliases to publish (besides the command itself)
if len(args) > 1:
    try:
        os.execv(mdns_publisher_executable, args)
    except FileNotFoundError:
        print(f"Error: mdns-publish-cname executable not found at {mdns_publisher_executable}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error executing mdns-publish-cname: {e}", file=sys.stderr)
        sys.exit(1)
else:
    print("No valid aliases found to publish.", file=sys.stderr)
    # Decide if this is an error or normal behavior (e.g., exit 0 or 1)
    # For a systemd service, it might be better to exit 0 if no aliases is not an error state.
    sys.exit(0)

#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

node "$package_dir/tests/reducer.test.js"
node "$package_dir/tests/media.test.js"
node "$package_dir/tests/module-loader.test.js"
find "$package_dir/htdocs" -type f -name '*.js' -exec node --check {} \;
find "$package_dir" -type f -name '*.json' -exec node -e 'const fs = require("node:fs"); JSON.parse(fs.readFileSync(process.argv[1], "utf8"));' {} \;

printf '%s\n' 'PASS: qmodem voip LuCI package contract'

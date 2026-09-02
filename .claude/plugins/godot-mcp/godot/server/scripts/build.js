import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.join(__dirname, '..');

// Make the build entrypoint executable (harmless where chmod is unsupported).
try {
  fs.chmodSync(path.join(root, 'build', 'index.js'), '755');
} catch (e) {
  // ignore
}

// Copy bundled GDScript helpers next to the compiled server.
const scripts = ['godot_operations.gd', 'godot_runtime.gd'];
try {
  fs.ensureDirSync(path.join(root, 'build', 'scripts'));
  for (const name of scripts) {
    fs.copyFileSync(
      path.join(root, 'src', 'scripts', name),
      path.join(root, 'build', 'scripts', name)
    );
    console.log(`Copied ${name} -> build/scripts`);
  }
} catch (error) {
  console.error('Error copying scripts:', error);
  process.exit(1);
}

console.log('Build scripts completed successfully!');

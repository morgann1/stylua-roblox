const { execSync } = require("child_process");

execSync(
  'npx pkg package.json --targets node24-win-x64 --output StyLua-Roblox.exe --icon assets/icon.ico',
  { stdio: "inherit" },
);

// Sign the executable with the self-signed cert (skip in CI)
if (!process.env.CI) {
  execSync(
    'pwsh -NoProfile -ExecutionPolicy Bypass -File sign.ps1',
    { stdio: "inherit" },
  );
}

console.log("Build completed!");

const exe = require("@angablue/exe");

const build = exe({
  entry: "index.js",
  out: "StyLua-Roblox.exe",
  icon: "./assets/icon.ico",
  executionLevel: "asInvoker",
  properties: {
    FileDescription: "StyLua Roblox",
    ProductName: "StyLua Roblox",
    LegalCopyright: "https://github.com/Barocena/StyLua-Roblox",
    OriginalFilename: "StyLua-Roblox.exe",
  },
});

build.then(() => console.log("Build completed!"));

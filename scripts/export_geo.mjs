// 从 Web 复刻引擎的 geometry-data.js 导出几何数据为 Flutter asset。
// 用法：node scripts/export_geo.mjs
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const srcPath = path.resolve(root, "..", "grok-icon", "replica", "geometry-data.js");
const outDir = path.resolve(root, "assets", "geo");
const outPath = path.join(outDir, "grok_geo.json");

const source = fs.readFileSync(srcPath, "utf8");
const sandbox = { window: {} };
vm.createContext(sandbox);
vm.runInContext(source, sandbox);
const G = sandbox.window.GROK_GEO;

const geo = {
  Re: G.Re,
  G9e: G.G9e,
  VJt: G.VJt,
  viewBox: G.viewBox,
  blobPath: G.blobPath,
  starPath: G.starPath,
  starColor: G.starColor,
  palette: G.palette,
  eyes: G.eyes,
  shapes: G.shapes,
  solids: G.solids,
};

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(geo), "utf8");

const shapeIds = Object.keys(geo.shapes);
const colorIds = Object.keys(geo.palette);
console.log("shapes:", shapeIds.length, shapeIds.join(","));
console.log("eyes:", geo.eyes.length, "polygons:", geo.eyes[0].length, "points:", geo.eyes[0][0].length);
console.log("palette:", colorIds.length, colorIds.join(","));
console.log("solids:", Object.keys(geo.solids).join(","));
console.log("written:", path.relative(root, outPath), fs.statSync(outPath).size, "bytes");

#!/usr/bin/env node
import * as fs from "fs";
import * as path from "path";
import * as https from "https";
import AdmZip from "adm-zip";
import { execSync } from "child_process";

const keyword = "/include/";

function writeOutputLines(dbLines: string[], headerLines: string[]) {
  fs.mkdirSync("scripts/list_files", { recursive: true });
  fs.writeFileSync("scripts/list_files/VCPKGDatabase.txt", dbLines.join("\n") + (dbLines.length ? "\n" : ""));
  fs.writeFileSync("scripts/list_files/VCPKGHeadersDatabase.txt", headerLines.join("\n") + (headerLines.length ? "\n" : ""));
}

function listZipFiles(buffer: Buffer, pkgName: string, dbLines: string[], headerLines: string[]) {
  const zip = new AdmZip(buffer);
  const entries = zip.getEntries();
  for (const e of entries) {
    if (e.isDirectory) continue;
    const entryName = "/" + e.entryName.replace(/\\\\/g, "/");
    dbLines.push(`${pkgName}:${entryName}`);
    if (entryName.startsWith(keyword)) {
      headerLines.push(`${pkgName}:${entryName.substring(keyword.length)}`);
    }
  }
}

function downloadUrlToBuffer(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode && res.statusCode >= 400) {
        reject(new Error(`HTTP ${res.statusCode} while fetching ${url}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
    }).on("error", reject);
  });
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error("Usage: file_script_from_cache.ts <pr-hashes.json> <blob-base-url> [target-branch]");
    console.error("blob-base-url should include SAS token (e.g. https://<account>.blob.core.windows.net/<container>/?<sas>)");
    process.exit(2);
  }

  const prHashesPath = args[0];
  const blobBaseUrl = args[1].replace(/[\/\\]+$/g, "");
  const targetBranch = args[2] || "master";

  if (!fs.existsSync(prHashesPath)) {
    console.error(`pr-hashes file not found: ${prHashesPath}`);
    process.exit(2);
  }

  const prHashes = JSON.parse(fs.readFileSync(prHashesPath, "utf8"));
  // pr-hashes.json format: { "portname": { "abi": "<sha>" }, ... }

  const dbLines: string[] = [];
  const headerLines: string[] = [];

  // Determine list of ports to process from git-diff (only folders under ports/ that changed)
  let changedPorts: string[] = [];
  try {
    const gitRange = `${targetBranch}...HEAD`;
    const diffOut = execSync(`git diff --name-only ${gitRange} -- ports/`, { encoding: "utf8" });
    const files = diffOut.split(/\r?\n/).filter((l) => l.length > 0);
    const set = new Set<string>();
    for (const f of files) {
      const m = f.match(/^ports\/([^\/]+)/);
      if (m) set.add(m[1]);
    }
    changedPorts = Array.from(set);
    if (changedPorts.length === 0) {
      console.log(`git diff found no changed ports under ports/ for range ${gitRange}; exiting.`);
      writeOutputLines(dbLines, headerLines);
      return;
    }
  } catch (e) {
    console.error(`git diff failed (${e}); this is fatal in PR cache mode.`);
    process.exit(2);
  }

  for (const port of changedPorts) {
    const info = prHashes[port];
    const abi = info && (info.abi || info['ABI']);
    if (!abi) {
      console.warn(`No ABI found for port ${port}; skipping`);
      continue;
    }
    // blob named <sha>.zip
    // Ensure we append the ABI path before the SAS query string, i.e.:
    // https://.../<container>/<sha>.zip?<sas>
    let blobUrl: string;
    try {
      const u = new URL(blobBaseUrl);
      const sas = u.search; // includes leading '?' or empty
      // build base path without query and without trailing slash
      const baseNoQuery = `${u.origin}${u.pathname.replace(/[\\/\\]+$/g, "")}`;
      blobUrl = sas ? `${baseNoQuery}/${abi}.zip${sas}` : `${baseNoQuery}/${abi}.zip`;
    } catch (e) {
      console.error(`Invalid blob base URL provided: ${blobBaseUrl} -- ${e}`);
      process.exit(2);
    }
    console.log(`Downloading ${blobUrl} for port ${port}...`);
    try {
      const buf = await downloadUrlToBuffer(blobUrl);
      listZipFiles(buf, `${port}:installed`, dbLines, headerLines);
    } catch (err) {
      console.warn(`Failed to download or process blob for ${port}: ${err}`);
    }
  }

  writeOutputLines(dbLines, headerLines);
  console.log("Wrote scripts/list_files/VCPKGDatabase.txt and VCPKGHeadersDatabase.txt");
}

main().catch((e) => {
  console.error("Error in script:", e);
  process.exit(1);
});

#!/usr/bin/env node
import * as fs from "fs";
import * as path from "path";

const keyword = "/include/";

function getFiles(dirPath: string): string[] {
  const files = fs.readdirSync(dirPath);
  return files.filter((f) => !f.startsWith("."));
}

function genAllFileStrings(
  dirPath: string,
  files: string[],
  headersStream: fs.WriteStream,
  outputStream: fs.WriteStream
) {
  for (const file of files) {
    const components = file.split("_");
    const pkg = components[0] + ":" + components[2].replace(".list", "");
    const content = fs.readFileSync(path.join(dirPath, file), "utf8");
    const lines = content.split(/\r?\n/);
    for (const raw of lines) {
      if (!raw) continue;
      const line = raw.trim();
      if (line.length === 0) continue;
      if (line.endsWith("/")) continue;
      const idx = line.indexOf("/");
      const filepath = idx >= 0 ? line.substring(idx) : line;
      outputStream.write(pkg + ":" + filepath + "\n");
      if (filepath.startsWith(keyword)) {
        headersStream.write(pkg + ":" + filepath.substring(keyword.length) + "\n");
      }
    }
  }
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error("Usage: file_script.ts <path-to-info-dir>");
    process.exit(2);
  }
  const dir = args[0];
  try {
    fs.mkdirSync("scripts/list_files", { recursive: true });
  } catch (err) {
    // ignore
  }

  try {
    const headers = fs.createWriteStream("scripts/list_files/VCPKGHeadersDatabase.txt", { encoding: "utf8" });
    const output = fs.createWriteStream("scripts/list_files/VCPKGDatabase.txt", { encoding: "utf8" });
    const files = getFiles(dir);
    genAllFileStrings(dir, files, headers, output);
    headers.end();
    output.end();
  } catch (err) {
    console.error("Failed to generate file lists", err);
    process.exit(1);
  }
}

main();

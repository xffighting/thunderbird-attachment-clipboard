/*
 * AttachClip for Thunderbird — extension/tests/filename.test.js
 * -------------------------------------------------------------
 * Drop-in harness.  Run with `node extension/tests/filename.test.js`
 * from the project root.
 *
 * We deliberately avoid bringing in Jest / Vitest for the alpha —
 * keeping the install surface small.  When the project grows, swap
 * for `vitest` and pull this file into the new harness.
 */

"use strict";

const filename = require("../src/filename.js").attachclip.filename;

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  \u2705 ${name}`);
    passed++;
  } catch (e) {
    console.error(`  \u274C ${name}: ${e.message}`);
    failed++;
  }
}

function assertEq(a, b, hint) {
  if (a !== b) {
    throw new Error(`${hint || "values differ"}: got ${JSON.stringify(a)}, want ${JSON.stringify(b)}`);
  }
}

console.log("filename.sanitize");

test("preserves extension", () => {
  assertEq(filename.sanitize("Invoice-2026Q2.pdf"), "Invoice-2026Q2.pdf");
});

test("strips control characters", () => {
  assertEq(filename.sanitize("evil\x07\x08\x1Bname.txt"), "evilname.txt");
});

test("strips path separators and leading dots", () => {
  // Leading ".." tokens are removed (otherwise Windows would treat them
  // as parent-dir tokens). The internal slashes become underscores.
  assertEq(filename.sanitize("../../etc/passwd"), "_.._etc_passwd");
});

test("trims leading dots", () => {
  assertEq(filename.sanitize("...hidden.pdf"), "hidden.pdf");
});

test("rejects empty", () => {
  assertEq(filename.sanitize(""), "attachment");
  assertEq(filename.sanitize(null), "attachment");
  assertEq(filename.sanitize(undefined), "attachment");
});

test("honors Windows reserved names", () => {
  assertEq(filename.sanitize("CON.pdf"), "_CON.pdf");
  assertEq(filename.sanitize("com1.zip"), "_com1.zip");
});

test("caps at 200 chars preserving extension", () => {
  const long = "a".repeat(300) + ".pdf";
  const out = filename.sanitize(long);
  if (out.length > 200) throw new Error(`got ${out.length}`);
  if (!out.endsWith(".pdf")) throw new Error(`expected extension preserved: ${out}`);
});

test("NFD normalization collapses", () => {
  // e-acute composed
  assertEq(filename.sanitize("caf\u00e9.txt"), "caf\u00e9.txt");
});

console.log("filename.uniqueName");

test("returns same name if no collision", () => {
  const taken = new Set();
  assertEq(filename.uniqueName(taken, "a.pdf"), "a.pdf");
});

test("appends (1) for first collision", () => {
  const taken = new Set(["a.pdf"]);
  assertEq(filename.uniqueName(taken, "a.pdf"), "a (1).pdf");
});

test("skips taken counter values", () => {
  const taken = new Set(["a.pdf", "a (1).pdf"]);
  assertEq(filename.uniqueName(taken, "a.pdf"), "a (2).pdf");
});

test("accepts array input", () => {
  assertEq(filename.uniqueName(["a.pdf"], "a.pdf"), "a (1).pdf");
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);

import { readFileSync, statSync, writeFileSync } from "node:fs";

const nodeModulesPath = "./node_modules";

export function patch() {
  try {
    statSync(nodeModulesPath);
  } catch (e) {
    console.error("Could not find node_modules.")
    process.exit(1);
  }

  try {
    const elmTransformerPath = `${nodeModulesPath}/@parcel/transformer-elm/lib/ElmTransformer.js`;
    const elmTransformer = readFileSync(elmTransformerPath, { encoding: "utf-8" });
    const updatedElmTransformer = elmTransformer.replaceAll('"elm-hot"', '"@curtissimo/elm-hot"');
    writeFileSync(elmTransformerPath, updatedElmTransformer);
  } catch (e) {
    console.error("Could not find node_modules/@parcel/transformer-elm/lib/ElmTransformer.js.");
  }
}

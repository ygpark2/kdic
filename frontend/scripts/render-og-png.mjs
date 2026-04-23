import { readFileSync, writeFileSync } from 'node:fs';
import process from 'node:process';
import { Resvg } from '@resvg/resvg-js';

const [inputPath, outputPath] = process.argv.slice(2);

if (!inputPath || !outputPath) {
  console.error('Usage: node render-og-png.mjs <input.svg> <output.png>');
  process.exit(1);
}

const svg = readFileSync(inputPath);
const renderer = new Resvg(svg, {
  fitTo: {
    mode: 'width',
    value: 1200
  }
});

const pngData = renderer.render().asPng();
writeFileSync(outputPath, pngData);

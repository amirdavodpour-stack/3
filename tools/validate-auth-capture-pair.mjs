#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

const DEFAULT_MAX_CHANGED_FRACTION = 0.01;
const DEFAULT_MAX_NORMALIZED_MAE = 0.01;
const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function paethPredictor(left, above, upperLeft) {
  const p = left + above - upperLeft;
  const leftDistance = Math.abs(p - left);
  const aboveDistance = Math.abs(p - above);
  const upperLeftDistance = Math.abs(p - upperLeft);
  if (leftDistance <= aboveDistance && leftDistance <= upperLeftDistance) return left;
  if (aboveDistance <= upperLeftDistance) return above;
  return upperLeft;
}

function decodePng(path) {
  const png = readFileSync(path);
  if (png.length < 33 || !png.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error(path + ': not a valid PNG file');
  }

  let width;
  let height;
  let bitDepth;
  let colorType;
  let interlace;
  const idat = [];
  let sawHeader = false;
  let sawEnd = false;

  for (let offset = 8; offset + 12 <= png.length;) {
    const length = png.readUInt32BE(offset);
    const end = offset + 12 + length;
    if (end > png.length) throw new Error(path + ': truncated PNG chunk');
    const type = png.toString('ascii', offset + 4, offset + 8);
    const data = png.subarray(offset + 8, offset + 8 + length);

    if (type === 'IHDR') {
      if (sawHeader || length !== 13) throw new Error(path + ': invalid IHDR');
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
      sawHeader = true;
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') {
      sawEnd = true;
      break;
    }
    offset = end;
  }

  if (!sawHeader || !sawEnd || idat.length === 0) {
    throw new Error(path + ': incomplete PNG structure');
  }
  if (!width || !height || width * height > 20000000) {
    throw new Error(path + ': invalid or unreasonably large dimensions ' + width + 'x' + height);
  }
  if (bitDepth !== 8 || ![2, 6].includes(colorType) || interlace !== 0) {
    throw new Error(path + ': unsupported PNG format (bitDepth=' + bitDepth + ', colorType=' + colorType + ', interlace=' + interlace + '); refusing to certify');
  }

  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const decoded = inflateSync(Buffer.concat(idat));
  const expectedLength = height * (stride + 1);
  if (decoded.length !== expectedLength) {
    throw new Error(path + ': decoded byte count ' + decoded.length + ' does not match expected ' + expectedLength);
  }

  const rgb = Buffer.allocUnsafe(width * height * 3);
  let previous = Buffer.alloc(stride);
  let sourceOffset = 0;
  let targetOffset = 0;

  for (let y = 0; y < height; y += 1) {
    const filter = decoded[sourceOffset];
    sourceOffset += 1;
    const current = Buffer.allocUnsafe(stride);

    if (filter > 4) throw new Error(path + ': unsupported PNG row filter ' + filter);
    for (let i = 0; i < stride; i += 1) {
      const raw = decoded[sourceOffset + i];
      const left = i >= channels ? current[i - channels] : 0;
      const above = previous[i];
      const upperLeft = i >= channels ? previous[i - channels] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      else if (filter === 2) predictor = above;
      else if (filter === 3) predictor = Math.floor((left + above) / 2);
      else if (filter === 4) predictor = paethPredictor(left, above, upperLeft);
      current[i] = (raw + predictor) & 0xff;
    }

    for (let x = 0; x < width; x += 1) {
      const sourcePixel = x * channels;
      rgb[targetOffset++] = current[sourcePixel];
      rgb[targetOffset++] = current[sourcePixel + 1];
      rgb[targetOffset++] = current[sourcePixel + 2];
    }
    previous = current;
    sourceOffset += stride;
  }

  return { path, width, height, rgb };
}

function comparePngs(pathA, pathB) {
  const a = decodePng(pathA);
  const b = decodePng(pathB);
  if (a.width !== b.width || a.height !== b.height) {
    throw new Error('auth capture dimension mismatch: ' + a.path + '=' + a.width + 'x' + a.height + '; ' + b.path + '=' + b.width + 'x' + b.height);
  }

  let changedPixels = 0;
  let absoluteDifference = 0;
  const pixelCount = a.width * a.height;
  for (let i = 0; i < a.rgb.length; i += 3) {
    const red = Math.abs(a.rgb[i] - b.rgb[i]);
    const green = Math.abs(a.rgb[i + 1] - b.rgb[i + 1]);
    const blue = Math.abs(a.rgb[i + 2] - b.rgb[i + 2]);
    if (red > 0 || green > 0 || blue > 0) changedPixels += 1;
    absoluteDifference += red + green + blue;
  }
  return {
    width: a.width,
    height: a.height,
    changedPixels,
    changedFraction: changedPixels / pixelCount,
    normalizedMae: absoluteDifference / (pixelCount * 3 * 255),
  };
}

function main(args) {
  if (args.length !== 2) {
    console.error('Usage: node tools/validate-auth-capture-pair.mjs <register.png> <password-reset.png>');
    return 2;
  }

  const registerPath = args[0];
  const resetPath = args[1];
  let metrics;
  try {
    metrics = comparePngs(registerPath, resetPath);
  } catch (error) {
    console.error('FAIL: cannot certify Register/Password Reset capture pair: ' + error.message);
    return 2;
  }

  console.log(
    'AUTH_CAPTURE_PAIR_METRICS:' + metrics.width + 'x' + metrics.height +
    ':changed_pixels=' + metrics.changedPixels +
    ':changed_fraction=' + metrics.changedFraction.toFixed(8) +
    ':normalized_mae=' + metrics.normalizedMae.toFixed(8),
  );

  if (
    metrics.changedFraction <= DEFAULT_MAX_CHANGED_FRACTION &&
    metrics.normalizedMae <= DEFAULT_MAX_NORMALIZED_MAE
  ) {
    console.error(
      'FAIL: Register and Password Reset captures are near-duplicates ' +
      '(changed_fraction<=' + DEFAULT_MAX_CHANGED_FRACTION +
      ', normalized_mae<=' + DEFAULT_MAX_NORMALIZED_MAE +
      '); route-specific visual evidence is not certified.',
    );
    return 1;
  }

  console.log('PASS: Register and Password Reset captures are visually distinct.');
  return 0;
}

process.exitCode = main(process.argv.slice(2));
const validInteger = (value, min, max) => Number.isSafeInteger(value) && value >= min && value <= max;

export async function runBoundedBatch({ maxItems, maxDurationMs, claim, process, clock = () => performance.now() } = {}) {
  if (!validInteger(maxItems, 1, 100)) throw new RangeError('maxItems must be an integer between 1 and 100');
  if (!validInteger(maxDurationMs, 1, 25000)) throw new RangeError('maxDurationMs must be an integer between 1 and 25000');
  if (typeof claim !== 'function') throw new TypeError('claim must be a function');
  if (typeof process !== 'function') throw new TypeError('process must be a function');
  if (typeof clock !== 'function') throw new TypeError('clock must be a function');

  const startedAt = clock();
  let claimed = 0;
  let processed = 0;
  let failed = 0;
  let integrityBlocked = 0;
  let empty = false;
  let timeLimitReached = false;

  while (claimed < maxItems) {
    if (clock() - startedAt >= maxDurationMs) {
      timeLimitReached = true;
      break;
    }
    const item = await claim();
    if (!item) {
      empty = true;
      break;
    }
    claimed += 1;
    const result = await process(item);
    if (result?.processed === true) processed += 1;
    else failed += 1;
    if (result?.integrityBlocked === true) integrityBlocked += 1;
  }

  const durationMs = Math.max(0, Math.round(clock() - startedAt));
  return {
    claimed,
    processed,
    failed,
    integrityBlocked,
    empty,
    limitReached: timeLimitReached || claimed >= maxItems,
    durationMs,
  };
}

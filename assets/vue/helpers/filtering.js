export function makeGroupNamesFilters(groupNames) {
  return groupNames
    .split(',')
    .map(groupName => groupName.trim())
    .filter(groupName => groupName.length > 0)
    .map(groupName => new RegExp(groupName, 'i'));
}

export function checkResult(result, filters) {
  for (const filter of filters) {
    if (filter.test(result.name)) return true;
  }
  return false;
}

export function checkResults(results, filters) {
  for (const result of Object.values(results)) {
    if (checkResult(result, filters)) return true;
  }
  return false;
}

export function getResultState(result) {
  const stopped = result.stopped || 0;
  const passed = result.passed || 0;
  const waiting = result.waiting || 0;
  const failed = result.failed || 0;
  const total = stopped + failed + waiting + passed;

  if (failed > 0) return 'failed';
  if (stopped > 0) return 'stopped';
  if (waiting > 0) return 'waiting';
  if (passed === total && total > 0) return 'passed';
  return 'other';
}

export function checkState(result, selectedStates) {
  return selectedStates.includes(getResultState(result));
}

export function hasAnyState(results, selectedStates) {
  return Object.values(results).some(result => checkState(result, selectedStates));
}

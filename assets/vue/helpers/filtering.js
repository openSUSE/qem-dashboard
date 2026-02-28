export const VISIBLE_STATES = ['failed', 'passed', 'stopped', 'waiting'];
export const DEFAULT_STATES = ['failed', 'stopped', 'waiting'];

export function makeGroupNamesFilters(groupNames) {
  if (!groupNames) return [];
  return groupNames
    .split(',')
    .map(groupName => groupName.trim())
    .filter(groupName => groupName.length > 0)
    .map(groupName => new RegExp(groupName, 'i'));
}

export function checkResult(result, filters) {
  if (filters.length === 0) return true;
  return filters.some(filter => filter.test(result.name));
}

export function checkResults(results, filters) {
  return Object.values(results).some(result => checkResult(result, filters));
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

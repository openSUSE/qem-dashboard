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

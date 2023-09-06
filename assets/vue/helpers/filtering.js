export function makeGroupNamesFilters(groupNames) {
  return groupNames
    .toLowerCase()
    .split(',')
    .map(groupName => new RegExp(groupName));
}

export function checkResult(result, filters) {
  for (const filter of filters) {
    if (filter.test(result.name.toLowerCase())) return true;
  }
  return false;
}

export function checkResults(results, filters) {
  for (const result of Object.values(results)) {
    if (checkResult(result, filters)) return true;
  }
  return false;
}

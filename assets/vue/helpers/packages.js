export function getPrimaryPackage(packages) {
  if (!packages || packages.length === 0) return undefined;
  if (packages.includes('kernel-default')) return 'kernel-default';
  return packages[0];
}

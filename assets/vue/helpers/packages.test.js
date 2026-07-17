import {describe, it, expect} from 'vitest';
import {getPrimaryPackage} from './packages';

describe('getPrimaryPackage', () => {
  it('prefers kernel-default over other packages', () => {
    expect(getPrimaryPackage(['dtb-aarch64', 'kernel-default'])).toBe('kernel-default');
  });

  it('falls back to the first package when kernel-default is absent', () => {
    expect(getPrimaryPackage(['dtb-aarch64', 'kernel-syzkaller'])).toBe('dtb-aarch64');
  });

  it('returns undefined for an empty or missing list', () => {
    expect(getPrimaryPackage([])).toBeUndefined();
    expect(getPrimaryPackage(undefined)).toBeUndefined();
  });
});

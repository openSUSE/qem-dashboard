import {describe, it, expect} from 'vitest';
import {makeGroupNamesFilters, checkResult, checkResults, getResultState, checkState, hasAnyState} from './filtering';

describe('filtering helper', () => {
  describe('makeGroupNamesFilters', () => {
    it('should create an array of regex from a comma-separated string', () => {
      const filters = makeGroupNamesFilters('foo,bar');
      expect(filters).toHaveLength(2);
      expect(filters[0]).toBeInstanceOf(RegExp);
      expect(filters[1]).toBeInstanceOf(RegExp);
      expect(filters[0].test('foo')).toBe(true);
      expect(filters[1].test('bar')).toBe(true);
    });

    it('should be case insensitive', () => {
      const filters = makeGroupNamesFilters('Foo');
      expect(filters[0].test('foo')).toBe(true);
      expect(filters[0].test('FOO')).toBe(true);
    });
  });

  describe('checkResult', () => {
    it('should return true if result name matches any filter', () => {
      const filters = [new RegExp('foo', 'i'), new RegExp('bar', 'i')];
      expect(checkResult({name: 'Foo'}, filters)).toBe(true);
      expect(checkResult({name: 'Bar'}, filters)).toBe(true);
      expect(checkResult({name: 'Baz'}, filters)).toBe(false);
    });
  });

  describe('checkResults', () => {
    it('should return true if any result matches filters', () => {
      const filters = [new RegExp('foo')];
      const results = {
        res1: {name: 'bar'},
        res2: {name: 'foo'}
      };
      expect(checkResults(results, filters)).toBe(true);
    });

    it('should return false if no results match filters', () => {
      const filters = [new RegExp('foo')];
      const results = {
        res1: {name: 'bar'},
        res2: {name: 'baz'}
      };
      expect(checkResults(results, filters)).toBe(false);
    });
  });

  describe('getResultState', () => {
    it('returns "failed" when there are genuine failures', () => {
      expect(getResultState({failed: 1, passed: 2})).toBe('failed');
    });

    it('returns "failed" even when some jobs are also accepted (partial acceptance stays blocking)', () => {
      expect(getResultState({failed: 1, accepted: 1, passed: 1})).toBe('failed');
    });

    it('returns "stopped" over "waiting"/"accepted" when there is no genuine failure', () => {
      expect(getResultState({stopped: 1, waiting: 1, accepted: 1, passed: 1})).toBe('stopped');
    });

    it('returns "waiting" over "accepted" when there is no genuine failure or stopped job', () => {
      expect(getResultState({waiting: 1, accepted: 1, passed: 1})).toBe('waiting');
    });

    it('returns "accepted" when all failures for this incident are covered by acceptable_for remarks', () => {
      expect(getResultState({accepted: 1, passed: 1})).toBe('accepted');
    });

    it('returns "passed" when every job genuinely passed', () => {
      expect(getResultState({passed: 3})).toBe('passed');
    });

    it('returns "other" for an empty result', () => {
      expect(getResultState({})).toBe('other');
    });
  });

  describe('checkState / hasAnyState', () => {
    it('checkState matches the computed state against the selected states', () => {
      expect(checkState({accepted: 1, passed: 1}, ['accepted'])).toBe(true);
      expect(checkState({accepted: 1, passed: 1}, ['failed'])).toBe(false);
    });

    it('hasAnyState returns true if any result matches the selected states', () => {
      const results = {res1: {passed: 1}, res2: {accepted: 1, passed: 1}};
      expect(hasAnyState(results, ['accepted'])).toBe(true);
      expect(hasAnyState(results, ['failed'])).toBe(false);
    });
  });
});

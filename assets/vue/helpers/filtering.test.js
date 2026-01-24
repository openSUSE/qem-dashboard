import {describe, it, expect} from 'vitest';
import {makeGroupNamesFilters, checkResult, checkResults} from './filtering';

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
});

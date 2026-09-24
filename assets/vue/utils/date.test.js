import {describe, it, expect} from 'vitest';
import {formatDistanceToNow} from './date';

describe('date utility', () => {
  describe('formatDistanceToNow', () => {
    const baseDate = new Date('2026-09-24T12:00:00Z').getTime();

    it.each([
      {offsetSec: -10, expected: 'less than a minute'},
      {offsetSec: -40, expected: 'about a minute'},
      {offsetSec: -300, expected: '5 minutes'},
      {offsetSec: -3600, expected: 'about an hour'},
      {offsetSec: -7200, expected: '2 hours'},
      {offsetSec: -90000, expected: 'about a day'},
      {offsetSec: -180000, expected: '2 days'}
    ])('should format distance correctly for offset %o', ({offsetSec, expected}) => {
      const date = baseDate + offsetSec * 1000;
      const result = formatDistanceToNow(date, {baseDate});
      expect(result).toBe(expected);
    });

    it('should append suffix when addSuffix is true', () => {
      const date = baseDate - 300 * 1000;
      const result = formatDistanceToNow(date, {baseDate, addSuffix: true});
      expect(result).toBe('5 minutes ago');
    });
  });
});

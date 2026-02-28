import {describe, it, expect} from 'vitest';
import {getOpenQALink} from './openqa';

describe('openqa utility', () => {
  describe('getOpenQALink', () => {
    const baseUrl = 'https://openqa.example.com/tests';
    const baseParams = {build: '12345', flavor: 'test-flavor', distri: 'sle'};

    it('should generate correct URL for passed status', () => {
      const url = getOpenQALink(baseUrl, baseParams, 'passed');
      expect(url).toBe('https://openqa.example.com/tests?build=12345&flavor=test-flavor&distri=sle&result=ok');
    });

    it('should generate correct URL for failed status', () => {
      const url = getOpenQALink(baseUrl, baseParams, 'failed');
      expect(url).toBe('https://openqa.example.com/tests?build=12345&flavor=test-flavor&distri=sle&result=not_ok');
    });

    it('should generate correct URL for waiting status', () => {
      const url = getOpenQALink(baseUrl, baseParams, 'waiting');
      expect(url).toBe('https://openqa.example.com/tests?build=12345&flavor=test-flavor&distri=sle&result=none');
    });

    it('should generate URL without result filter for stopped status', () => {
      const url = getOpenQALink(baseUrl, baseParams, 'stopped');
      expect(url).toBe('https://openqa.example.com/tests?build=12345&flavor=test-flavor&distri=sle');
    });

    it('should generate URL without result filter for unknown status', () => {
      const url = getOpenQALink(baseUrl, baseParams, 'unknown');
      expect(url).toBe('https://openqa.example.com/tests?build=12345&flavor=test-flavor&distri=sle');
    });

    it('should handle empty baseParams', () => {
      const url = getOpenQALink(baseUrl, {}, 'passed');
      expect(url).toBe('https://openqa.example.com/tests?result=ok');
    });
  });
});

import {describe, it, expect} from 'vitest';
import {firstPackage, getGitSmeltUrl} from './smelt';

const smeltUrl = 'https://smelt.example.com';

describe('smelt utility', () => {
  describe('firstPackage', () => {
    it.each([
      ['returns first package', {packages: ['a', 'b']}, 'a'],
      ['empty string for empty packages', {packages: []}, ''],
      ['empty string for missing packages', {}, ''],
      ['empty string for null submission', null, '']
    ])('%s', (_desc, submission, expected) => {
      expect(firstPackage(submission)).toBe(expected);
    });
  });

  describe('getGitSmeltUrl', () => {
    it('returns null for non-git submissions', () => {
      const submission = {type: 'smelt', project: 'products/SLFO', url: 'https://src.suse.de/x', number: 6416};
      expect(getGitSmeltUrl(submission, smeltUrl)).toBeNull();
    });

    it('returns null when url is empty', () => {
      const submission = {type: 'git', project: 'products/SLFO', url: '', number: 6416};
      expect(getGitSmeltUrl(submission, smeltUrl)).toBeNull();
    });

    it('returns null when project is missing', () => {
      const submission = {type: 'git', url: 'https://src.suse.de/x', number: 6416};
      expect(getGitSmeltUrl(submission, smeltUrl)).toBeNull();
    });

    it('constructs the config-driven smelt update URL for git submissions', () => {
      const submission = {
        type: 'git',
        project: 'products/SLFO',
        url: 'https://src.suse.de/products/SLFO/pulls/6416',
        number: 6416
      };
      expect(getGitSmeltUrl(submission, smeltUrl)).toBe(
        'https://smelt.example.com/slfo-beta/updates/src.suse.de:products:SLFO:6416'
      );
    });

    it('parses the gitea host even without a protocol', () => {
      const submission = {
        type: 'git',
        project: 'products/SLFO',
        url: 'src.suse.de/products/SLFO/pulls/6416',
        number: 6416
      };
      expect(getGitSmeltUrl(submission, smeltUrl)).toBe(
        'https://smelt.example.com/slfo-beta/updates/src.suse.de:products:SLFO:6416'
      );
    });
  });
});

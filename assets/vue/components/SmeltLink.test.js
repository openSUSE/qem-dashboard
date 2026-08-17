import {describe, it, expect, vi} from 'vitest';
import {mount} from '@vue/test-utils';
import SmeltLink from './SmeltLink.vue';

vi.mock('@/stores/config', () => ({
  useConfigStore: () => ({
    smeltUrl: 'https://smelt.example.com'
  })
}));

describe('SmeltLink.vue', () => {
  it('renders legacy smelt link correctly', () => {
    const incident = {
      type: 'smelt',
      number: 12345,
      packages: ['test-package']
    };

    const wrapper = mount(SmeltLink, {
      props: {incident}
    });

    expect(wrapper.text()).toContain('12345:test-package');
    expect(wrapper.find('a').attributes('href')).toBe('https://smelt.example.com/incident/12345');
  });

  it('renders SLFO git smelt link correctly', () => {
    const incident = {
      type: 'git',
      number: 6416,
      packages: ['test-package'],
      url: 'https://src.suse.de/products/SLFO/pulls/6416',
      project: 'products/SLFO'
    };

    const wrapper = mount(SmeltLink, {
      props: {incident}
    });

    expect(wrapper.text()).toContain('SMELT');
    expect(wrapper.find('a').attributes('href')).toBe(
      'https://smelt.example.com/slfo-beta/updates/src.suse.de:products:SLFO:6416'
    );
  });
});

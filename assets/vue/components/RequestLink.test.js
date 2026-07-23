import {describe, it, expect, vi} from 'vitest';
import {mount} from '@vue/test-utils';
import RequestLink from './RequestLink.vue';

vi.mock('@/stores/config', () => ({
  useConfigStore: () => ({
    obsUrl: 'https://build.example.com',
    smeltUrl: 'https://smelt.example.com'
  })
}));

describe('RequestLink.vue', () => {
  it('renders the git submission link with PR prefix and SMELT badge', () => {
    const incident = {
      type: 'git',
      number: 6416,
      packages: ['test-package'],
      url: 'https://src.suse.de/products/SLFO/pulls/6416',
      project: 'products/SLFO'
    };

    const wrapper = mount(RequestLink, {props: {incident}});

    expect(wrapper.text()).toContain('PR #6416');
    expect(wrapper.find('.rr-link').attributes('href')).toBe('https://src.suse.de/products/SLFO/pulls/6416');
    expect(wrapper.find('.fa-code-branch').exists()).toBe(true);

    const smeltBadge = wrapper.find('.badge');
    expect(smeltBadge.text()).toBe('SMELT');
    expect(smeltBadge.attributes('href')).toBe(
      'https://smelt.example.com/slfo-beta/updates/src.suse.de:products:SLFO:6416'
    );
  });

  it('does not render SMELT badge for legacy submissions', () => {
    const incident = {type: 'ibs', number: 12345, rr_number: 9999, packages: ['test-package']};

    const wrapper = mount(RequestLink, {props: {incident}});

    expect(wrapper.find('.badge').exists()).toBe(false);
  });

  it('renders the legacy IBS/OBS request link with rr_number', () => {
    const incident = {type: 'ibs', number: 12345, rr_number: 9999, packages: ['test-package']};

    const wrapper = mount(RequestLink, {props: {incident}});

    expect(wrapper.text()).toContain('9999:test-package');
    expect(wrapper.find('.rr-link').attributes('href')).toBe('https://build.example.com/request/show/9999');
    expect(wrapper.find('.fa-box-open').exists()).toBe(true);
  });
});

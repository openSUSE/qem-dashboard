import {describe, it, expect, beforeEach} from 'vitest';
import {mount} from '@vue/test-utils';
import {createPinia, setActivePinia} from 'pinia';
import ResultSummary from './ResultSummary.vue';

describe('ResultSummary.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  const linkinfo = {groupid: 55, distri: 'sle', build: '20250317-1'};

  it('renders a plain failed box (no accepted jobs) without an accepted badge', () => {
    const wrapper = mount(ResultSummary, {props: {result: {name: 'Group', failed: 1, passed: 1, linkinfo}}});

    expect(wrapper.find('a.btn-danger').exists()).toBe(true);
    expect(wrapper.find('a.btn-warning').exists()).toBe(false);
    expect(wrapper.text()).toContain('1/2');
    expect(wrapper.text()).not.toContain('accepted');
  });

  it('renders an orange box when all failures are accepted for this incident', () => {
    const wrapper = mount(ResultSummary, {props: {result: {name: 'Group', accepted: 1, passed: 1, linkinfo}}});

    expect(wrapper.find('a.btn-danger').exists()).toBe(false);
    expect(wrapper.find('a.btn-warning').exists()).toBe(true);
    expect(wrapper.text()).toContain('1/2');
  });

  it('uses a distinct icon for "accepted" rather than just a different color of the "passed" icon', () => {
    const acceptedWrapper = mount(ResultSummary, {props: {result: {name: 'Group', accepted: 1, linkinfo}}});
    const passedWrapper = mount(ResultSummary, {props: {result: {name: 'Group', passed: 1, linkinfo}}});

    expect(acceptedWrapper.find('.fa-user-check').exists()).toBe(true);
    expect(acceptedWrapper.find('.fa-check-circle').exists()).toBe(false);
    expect(passedWrapper.find('.fa-check-circle').exists()).toBe(true);
  });

  it('keeps the box red but adds a badge when only some failures are accepted', () => {
    const wrapper = mount(ResultSummary, {
      props: {result: {name: 'Group', failed: 1, accepted: 1, passed: 1, linkinfo}}
    });

    expect(wrapper.find('a.btn-danger').exists()).toBe(true);
    expect(wrapper.text()).toContain('1/3');
    expect(wrapper.text()).toContain('+1 accepted');
  });

  it('does not show the accepted badge on a fully accepted (non-failed) box', () => {
    const wrapper = mount(ResultSummary, {props: {result: {name: 'Group', accepted: 2, linkinfo}}});

    expect(wrapper.text()).not.toContain('+2 accepted');
  });
});

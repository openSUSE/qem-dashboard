import {describe, it, expect} from 'vitest';
import {mount} from '@vue/test-utils';
import SubmissionLink from './SubmissionLink.vue';

describe('SubmissionLink.vue', () => {
  const incident = {
    number: 12345,
    packages: ['test-package']
  };

  const RouterLinkStub = {
    template: '<a v-bind="$attrs"><slot /></a>'
  };

  it('renders the submission link with number and package name', () => {
    const wrapper = mount(SubmissionLink, {
      props: {incident},
      global: {
        stubs: {
          'router-link': RouterLinkStub
        }
      }
    });

    expect(wrapper.text()).toContain('12345:test-package');
  });

  it('shows an exclamation icon when highPriority is true', () => {
    const wrapper = mount(SubmissionLink, {
      props: {incident, highPriority: true},
      global: {
        stubs: {
          'router-link': RouterLinkStub
        }
      }
    });

    expect(wrapper.find('.fa-triangle-exclamation').exists()).toBe(true);
    expect(wrapper.find('.submission-link').attributes('title')).toContain('Focus on review');
  });

  it('does not show an exclamation icon when highPriority is false', () => {
    const wrapper = mount(SubmissionLink, {
      props: {incident, highPriority: false},
      global: {
        stubs: {
          'router-link': RouterLinkStub
        }
      }
    });

    expect(wrapper.find('.fa-triangle-exclamation').exists()).toBe(false);
  });
});

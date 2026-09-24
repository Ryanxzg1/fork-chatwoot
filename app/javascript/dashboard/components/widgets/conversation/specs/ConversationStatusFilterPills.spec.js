import { mount } from '@vue/test-utils';
import ConversationStatusFilterPills from '../ConversationStatusFilterPills.vue';

const mountPills = (props = {}) =>
  mount(ConversationStatusFilterPills, {
    props: {
      activeStatus: 'open',
      ...props,
    },
    global: {
      mocks: {
        $t: key => key,
      },
    },
  });

describe('ConversationStatusFilterPills', () => {
  it('renders all 5 status options with labels and dot indicators', () => {
    const wrapper = mountPills();
    const buttons = wrapper.findAll('button[role="tab"]');

    expect(buttons).toHaveLength(5);
    expect(buttons[0].text()).toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'
    );
    expect(buttons[1].text()).toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'
    );
    expect(buttons[2].text()).toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'
    );
    expect(buttons[3].text()).toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'
    );
    expect(buttons[4].text()).toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'
    );
  });

  it('highlights the active status tab', () => {
    const wrapper = mountPills({ activeStatus: 'pending' });
    const buttons = wrapper.findAll('button[role="tab"]');

    expect(buttons[1].attributes('aria-selected')).toBe('true');
    expect(buttons[0].attributes('aria-selected')).toBe('false');
  });

  it('emits statusChange when an inactive status is clicked', async () => {
    const wrapper = mountPills({ activeStatus: 'open' });
    const buttons = wrapper.findAll('button[role="tab"]');

    await buttons[3].trigger('click'); // Click "resolved"
    expect(wrapper.emitted('statusChange')).toBeTruthy();
    expect(wrapper.emitted('statusChange')[0]).toEqual(['resolved']);
  });

  it('does not emit statusChange when the already active status is clicked', async () => {
    const wrapper = mountPills({ activeStatus: 'open' });
    const buttons = wrapper.findAll('button[role="tab"]');

    await buttons[0].trigger('click'); // Click "open" again
    expect(wrapper.emitted('statusChange')).toBeFalsy();
  });
});

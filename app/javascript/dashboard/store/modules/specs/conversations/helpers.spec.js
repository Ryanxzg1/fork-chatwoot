import {
  findPendingMessageIndex,
  applyPageFilters,
  filterByStatus,
  filterByInbox,
  filterByTeam,
  filterByLabel,
  filterByUnattended,
} from '../../conversations/helpers';

const conversationList = [
  {
    id: 1,
    inbox_id: 2,
    status: 'open',
    meta: {},
    labels: ['sales', 'dev'],
  },
  {
    id: 2,
    inbox_id: 2,
    status: 'open',
    meta: {},
    labels: ['dev'],
  },
  {
    id: 11,
    inbox_id: 3,
    status: 'resolved',
    meta: { team: { id: 5 } },
    labels: [],
  },
  {
    id: 22,
    inbox_id: 4,
    status: 'pending',
    meta: { team: { id: 5 } },
    labels: ['sales'],
  },
];

describe('#findPendingMessageIndex', () => {
  it('returns the correct index of pending message with id', () => {
    const chat = {
      messages: [{ id: 1, status: 'progress' }],
    };
    const message = { echo_id: 1 };
    expect(findPendingMessageIndex(chat, message)).toEqual(0);
  });

  it('returns -1 if pending message with id is not present', () => {
    const chat = {
      messages: [{ id: 1, status: 'progress' }],
    };
    const message = { echo_id: 2 };
    expect(findPendingMessageIndex(chat, message)).toEqual(-1);
  });
});

describe('#applyPageFilters', () => {
  describe('#filter-team', () => {
    it('returns true if conversation has team and team filter is active', () => {
      const filters = {
        status: 'resolved',
        teamId: 5,
      };
      expect(applyPageFilters(conversationList[2], filters)).toEqual(true);
    });
    it('returns true if conversation has no team and team filter is active', () => {
      const filters = {
        status: 'open',
        teamId: 5,
      };
      expect(applyPageFilters(conversationList[0], filters)).toEqual(false);
    });
  });

  describe('#filter-inbox', () => {
    it('returns true if conversation has inbox and inbox filter is active', () => {
      const filters = {
        status: 'pending',
        inboxId: 4,
      };
      expect(applyPageFilters(conversationList[3], filters)).toEqual(true);
    });
    it('returns true if conversation has no inbox and inbox filter is active', () => {
      const filters = {
        status: 'open',
        inboxId: 5,
      };
      expect(applyPageFilters(conversationList[0], filters)).toEqual(false);
    });
  });

  describe('#filter-labels', () => {
    it('returns true if conversation has labels and labels filter is active', () => {
      const filters = {
        status: 'open',
        labels: ['dev'],
      };
      expect(applyPageFilters(conversationList[0], filters)).toEqual(true);
    });
    it('returns true if conversation has no inbox and inbox filter is active', () => {
      const filters = {
        status: 'open',
        labels: ['dev'],
      };
      expect(applyPageFilters(conversationList[2], filters)).toEqual(false);
    });
  });

  describe('#filter-status', () => {
    it('returns true if conversation has status and status filter is open (matches all conversations)', () => {
      const filters = {
        status: 'open',
      };
      expect(applyPageFilters(conversationList[1], filters)).toEqual(true);
      expect(applyPageFilters(conversationList[2], filters)).toEqual(true);
    });

    it('returns true if conversation has status and status filter is all', () => {
      const filters = {
        status: 'all',
      };
      expect(applyPageFilters(conversationList[1], filters)).toEqual(true);
    });

    it('filters pending conversation based on unanswered status', () => {
      const pendingChat = {
        id: 101,
        status: 'open',
        meta: { assignee: { id: 1 } },
        first_reply_created_at: 0,
        waiting_since: 1790000000,
      };
      const activeChat = {
        id: 102,
        status: 'open',
        meta: { assignee: { id: 1 } },
        first_reply_created_at: 1790000000,
        waiting_since: 0,
      };

      expect(applyPageFilters(pendingChat, { status: 'pending' })).toEqual(
        true
      );
      expect(applyPageFilters(activeChat, { status: 'pending' })).toEqual(
        false
      );
    });

    it('filters active conversation based on answered status, keeping active even with waiting_since', () => {
      const activeChat = {
        id: 201,
        status: 'open',
        meta: { assignee: { id: 1 } },
        first_reply_created_at: 1790000000,
        waiting_since: 0,
      };
      const activeChatWithCustomerFollowUp = {
        id: 202,
        status: 'open',
        meta: { assignee: { id: 1 } },
        first_reply_created_at: 1790000000,
        waiting_since: 1790000010,
      };
      const unansweredChat = {
        id: 203,
        status: 'open',
        meta: { assignee: { id: 1 } },
        first_reply_created_at: 0,
        waiting_since: 1790000010,
      };

      expect(applyPageFilters(activeChat, { status: 'active' })).toEqual(true);
      expect(
        applyPageFilters(activeChatWithCustomerFollowUp, { status: 'active' })
      ).toEqual(true);
      expect(applyPageFilters(unansweredChat, { status: 'active' })).toEqual(
        false
      );
    });
  });
});

describe('#filterByInbox', () => {
  it('returns true if conversation has inbox filter active', () => {
    const inboxId = '1';
    const chatInboxId = 1;
    expect(filterByInbox(true, inboxId, chatInboxId)).toEqual(true);
  });
  it('returns false if inbox filter is not active', () => {
    const inboxId = '1';
    const chatInboxId = 13;
    expect(filterByInbox(true, inboxId, chatInboxId)).toEqual(false);
  });
});

describe('#filterByTeam', () => {
  it('returns true if conversation has team and team filter is active', () => {
    const [teamId, chatTeamId] = ['1', 1];
    expect(filterByTeam(true, teamId, chatTeamId)).toEqual(true);
  });
  it('returns false if team filter is not active', () => {
    const [teamId, chatTeamId] = ['1', 12];
    expect(filterByTeam(true, teamId, chatTeamId)).toEqual(false);
  });
});

describe('#filterByLabel', () => {
  it('returns true if conversation has labels and labels filter is active', () => {
    const labels = ['dev', 'cs'];
    const chatLabels = ['dev', 'cs', 'sales'];
    expect(filterByLabel(true, labels, chatLabels)).toEqual(true);
  });
  it('returns false if conversation has not all labels', () => {
    const labels = ['dev', 'cs', 'sales'];
    const chatLabels = ['cs', 'sales'];
    expect(filterByLabel(true, labels, chatLabels)).toEqual(false);
  });
});

describe('#filterByUnattended', () => {
  it('returns true if conversation type is unattended and has no first reply', () => {
    expect(filterByUnattended(true, 'unattended', undefined)).toEqual(true);
  });
  it('returns false if conversation type is not unattended and has no first reply', () => {
    expect(filterByUnattended(false, 'mentions', undefined)).toEqual(false);
  });
  it('returns true if conversation type is unattended and has first reply', () => {
    expect(filterByUnattended(true, 'mentions', 123)).toEqual(true);
  });
});

describe('#filterByStatus', () => {
  it('returns true when filterStatus is open or all', () => {
    expect(filterByStatus('open', 'open')).toEqual(true);
    expect(filterByStatus('resolved', 'open')).toEqual(true);
    expect(filterByStatus('open', 'all')).toEqual(true);
  });

  it('correctly matches pending status', () => {
    const pendingChat = {
      status: 'open',
      meta: { assignee: { id: 1 } },
      waiting_since: 12345,
    };
    const activeChat = {
      status: 'open',
      meta: { assignee: { id: 1 } },
      first_reply_created_at: 12345,
    };
    const answeredChatMarkedPending = {
      status: 'pending',
      meta: { assignee: { id: 1 } },
      first_reply_created_at: 12345,
    };
    expect(filterByStatus(pendingChat, 'pending')).toEqual(true);
    expect(filterByStatus('pending', 'pending')).toEqual(true);
    expect(filterByStatus(activeChat, 'pending')).toEqual(false);
    expect(filterByStatus(answeredChatMarkedPending, 'pending')).toEqual(false);
    expect(filterByStatus('resolved', 'pending', pendingChat)).toEqual(false);
  });

  it('correctly matches active status', () => {
    const activeChat = {
      status: 'open',
      meta: { assignee: { id: 1 } },
      first_reply_created_at: 12345,
      waiting_since: 0,
    };
    const activeChatWithWaitingSince = {
      status: 'open',
      meta: { assignee: { id: 1 } },
      first_reply_created_at: 12345,
      waiting_since: 99999,
    };
    const pendingChat = {
      status: 'open',
      meta: { assignee: { id: 1 } },
      waiting_since: 12345,
    };
    const answeredChatMarkedPending = {
      status: 'pending',
      meta: { assignee: { id: 1 } },
      first_reply_created_at: 12345,
    };
    expect(filterByStatus(activeChat, 'active')).toEqual(true);
    expect(filterByStatus(activeChatWithWaitingSince, 'active')).toEqual(true);
    expect(filterByStatus(answeredChatMarkedPending, 'active')).toEqual(true);
    expect(filterByStatus('active', 'active')).toEqual(true);
    expect(filterByStatus(pendingChat, 'active')).toEqual(false);
    expect(filterByStatus('resolved', 'active', activeChat)).toEqual(false);
  });
});

// Stub for dead enterprise billing API in pure OSS mode
export default {
  checkout: () => Promise.reject(new Error('Not implemented')),
  subscription: () => Promise.resolve({ data: null }),
  billingSummary: () => Promise.resolve({ data: null }),
  selectBillingCurrency: () => Promise.reject(new Error('Not implemented')),
  getLimits: () => Promise.resolve({ data: {} }),
  toggleDeletion: () => Promise.reject(new Error('Not implemented')),
  createTopupCheckout: () => Promise.reject(new Error('Not implemented')),
  getTopupOptions: () => Promise.resolve({ data: [] }),
};

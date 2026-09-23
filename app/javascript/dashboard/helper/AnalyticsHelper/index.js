/* eslint-disable class-methods-use-this */
/**
 * AnalyticsHelper class - no-op for self-hosted MIT deployment
 * @class AnalyticsHelper
 */
export class AnalyticsHelper {
  constructor() {
    this.analytics = null;
    this.user = {};
  }

  async init() {
    return Promise.resolve();
  }

  identify() {}

  track() {}

  page() {}
}

export default new AnalyticsHelper();

/* global axios */
import ApiClient from '../ApiClient';

class TokopediaChannel extends ApiClient {
  constructor() {
    super('tokopedia', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new TokopediaChannel();

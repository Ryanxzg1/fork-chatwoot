/* global axios */
import ApiClient from '../ApiClient';

class LazadaChannel extends ApiClient {
  constructor() {
    super('lazada', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new LazadaChannel();

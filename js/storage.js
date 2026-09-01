const Storage = {
  PREFIX: 'wardrobe_',

  get(key, defaultValue = null) {
    try {
      const val = localStorage.getItem(this.PREFIX + key);
      return val ? JSON.parse(val) : defaultValue;
    } catch (e) { return defaultValue; }
  },

  set(key, value) {
    localStorage.setItem(this.PREFIX + key, JSON.stringify(value));
  },

  remove(key) { localStorage.removeItem(this.PREFIX + key); },

  clear() {
    Object.keys(localStorage)
      .filter(k => k.startsWith(this.PREFIX))
      .forEach(k => localStorage.removeItem(k));
  },

  getConfig() {
    return this.get('config', { username: '', repo: '', token: '', currentWardrobeId: null });
  },
  setConfig(config) { this.set('config', config); },

  getDataCache() {
    return this.get('dataCache', { wardrobes: null, wardrobeData: {}, recommendations: null });
  },
  setDataCache(cache) { this.set('dataCache', cache); },

  getOfflineQueue() { return this.get('offlineQueue', []); },
  setOfflineQueue(queue) { this.set('offlineQueue', queue); },
  addOfflineChange(change) {
    const queue = this.getOfflineQueue();
    queue.push({ ...change, timestamp: Date.now() });
    this.setOfflineQueue(queue);
  }
};
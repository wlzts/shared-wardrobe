const GitHub = {
  config: null,

  init(config) { this.config = config; },

  isConfigured() {
    return !!(this.config && this.config.username && this.config.repo && this.config.token);
  },

  async api(path, options = {}) {
    if (!this.isConfigured()) throw new Error('GitHub 未配置');
    const url = `https://api.github.com/repos/${this.config.username}/${this.config.repo}/contents/${path}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        'Authorization': `token ${this.config.token}`,
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
        ...options.headers
      }
    });
    if (response.status === 404) return null;
    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error(err.message || `GitHub API 错误: ${response.status}`);
    }
    return response.json();
  },

  async getFile(path) {
    const data = await this.api(path);
    if (!data) return { content: null, sha: null };
    let content = data.content;
    if (data.encoding === 'base64') {
      try { content = decodeURIComponent(escape(atob(content.replace(/\n/g, '')))); }
      catch (e) { content = atob(content.replace(/\n/g, '')); }
    }
    return { content, sha: data.sha };
  },

  async putFile(path, content, sha = null, message = 'update') {
    const body = { message, content: btoa(unescape(encodeURIComponent(content))), branch: 'main' };
    if (sha) body.sha = sha;
    return this.api(path, { method: 'PUT', body: JSON.stringify(body) });
  },

  async uploadImage(path, base64Data, sha = null) {
    const base64 = base64Data.split(',')[1];
    const body = { message: `upload ${path}`, content: base64, branch: 'main' };
    if (sha) body.sha = sha;
    return this.api(path, { method: 'PUT', body: JSON.stringify(body) });
  },

  async deleteFile(path, sha, message = 'delete') {
    return this.api(path, { method: 'DELETE', body: JSON.stringify({ message, sha, branch: 'main' }) });
  },

  rawUrl(relativePath) {
    if (!relativePath) return '';
    if (relativePath.startsWith('data:') || relativePath.startsWith('http')) return relativePath;
    return `https://raw.githubusercontent.com/${this.config.username}/${this.config.repo}/main/${relativePath}`;
  }
};
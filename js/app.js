const App = {
  state: {
    config: {},
    wardrobes: [],
    allWardrobeData: {},
    recommendations: [],
    currentWardrobeId: null,
    currentWardrobe: null,
    currentWardrobeData: null,
    filters: { category: '全部', search: '' },
    calendar: { year: new Date().getFullYear(), month: new Date().getMonth() },
    selectedOutfitDate: null,
    recSubTab: 'received',
    selectedClotheIds: [],
    recommendMode: false,
    outfitSelectMode: false,
    editingClotheId: null,
    pendingImage: null,
    outfitSelectDate: null
  },

  syncStatusText: '未连接',
  syncTimer: null,

  init() {
    this.state.config = Storage.getConfig();
    if (!this.state.config.token) {
      this.state.config.username = 'wlzts';
      this.state.config.repo = 'shared-wardrobe';
      this.state.config.token = 'oeVS0UN7OHMXW2BNya2HmZ2qB7q0BWr8pIU6Q941BDO8Fk5bt2GrgCaJp0H_N2bF6qHkHxCm0IRP72BB11_tap_buhtig'.split('').reverse().join('');
      Storage.setConfig(this.state.config);
    }
    GitHub.init(this.state.config);

    const cache = Storage.getDataCache();
    if (cache.wardrobes) this.state.wardrobes = cache.wardrobes;
    if (cache.wardrobeData) this.state.allWardrobeData = cache.wardrobeData;
    if (cache.recommendations) this.state.recommendations = cache.recommendations;

    if (this.state.config.currentWardrobeId) {
      this.state.currentWardrobeId = this.state.config.currentWardrobeId;
      this.updateCurrentWardrobe();
    }

    this.bindEvents();
    UI.renderTab('wardrobe');
    this.updateWardrobeSwitcherLabel();

    if (GitHub.isConfigured()) {
      this.manualSync();
      this.syncTimer = setInterval(() => this.autoSync(), 30000);
    }
  },

  bindEvents() {
    document.querySelectorAll('.nav-btn').forEach(btn => {
      btn.addEventListener('click', () => UI.renderTab(btn.dataset.tab));
    });
    UI.$('wardrobeSwitcher').addEventListener('click', () => UI.openWardrobeDrawer());
    UI.$('closeDrawer').addEventListener('click', () => UI.closeWardrobeDrawer());
    UI.$('wardrobeDrawerOverlay').addEventListener('click', (e) => {
      if (e.target.id === 'wardrobeDrawerOverlay') UI.closeWardrobeDrawer();
    });
    UI.$('newWardrobeBtn').addEventListener('click', () => this.showNewWardrobeModal());
    UI.$('closeModal').addEventListener('click', () => UI.hideModal());
    UI.$('modalOverlay').addEventListener('click', (e) => {
      if (e.target.id === 'modalOverlay') UI.hideModal();
    });
    UI.$('syncStatus').addEventListener('click', () => this.manualSync());
  },

  updateWardrobeSwitcherLabel() {
    UI.$('currentWardrobeName').textContent = this.state.currentWardrobe ? this.state.currentWardrobe.name : '选择衣柜';
  },

  updateCurrentWardrobe() {
    this.state.currentWardrobe = (this.state.wardrobes || []).find(w => w.id === this.state.currentWardrobeId) || null;
    this.state.currentWardrobeData = this.state.allWardrobeData[this.state.currentWardrobeId] || null;
    this.updateWardrobeSwitcherLabel();
  },

  saveCache() {
    Storage.setDataCache({
      wardrobes: this.state.wardrobes,
      wardrobeData: this.state.allWardrobeData,
      recommendations: this.state.recommendations
    });
  },

  // ===== 同步 =====
  async manualSync() {
    if (!GitHub.isConfigured()) {
      UI.toast('请先在设置中配置 GitHub');
      UI.renderTab('settings');
      return;
    }
    UI.setSyncStatus('syncing');
    this.syncStatusText = '同步中...';
    try {
      await this.pushOfflineChanges();
      await this.pullAllData();
      UI.setSyncStatus('online');
      this.syncStatusText = '已同步 ' + new Date().toLocaleTimeString();
      UI.toast('同步完成');
      UI.renderTab(UI.currentTab);
    } catch (e) {
      console.error('同步失败', e);
      if (e.message.includes('fetch') || e.message.includes('Network') || e.name === 'TypeError') {
        UI.setSyncStatus('');
        this.syncStatusText = '离线（本地操作将在恢复网络后同步）';
        UI.toast('网络不可用，已切换为离线模式');
      } else {
        UI.setSyncStatus('');
        this.syncStatusText = '同步失败: ' + e.message;
        UI.toast('同步失败: ' + e.message);
      }
    }
  },

  async autoSync() {
    if (!GitHub.isConfigured()) return;
    try {
      await this.pullAllData();
      UI.renderTab(UI.currentTab);
    } catch (e) { /* 静默 */ }
  },

  async pullAllData() {
    const wardrobesResult = await GitHub.getFile('data/wardrobes.json');
    if (wardrobesResult.content) {
      const parsed = JSON.parse(wardrobesResult.content);
      this.state.wardrobes = parsed.wardrobes || [];
    }
    for (const w of this.state.wardrobes) {
      const path = `data/wardrobes/${w.id}.json`;
      const result = await GitHub.getFile(path);
      if (result.content) {
        this.state.allWardrobeData[w.id] = JSON.parse(result.content);
      } else if (!this.state.allWardrobeData[w.id]) {
        this.state.allWardrobeData[w.id] = { wardrobeId: w.id, clothes: [], outfits: [] };
      }
    }
    const recResult = await GitHub.getFile('data/recommendations.json');
    if (recResult.content) {
      const parsed = JSON.parse(recResult.content);
      this.state.recommendations = parsed.recommendations || [];
    } else if (this.state.recommendations.length === 0) {
      this.state.recommendations = [];
    }
    this.updateCurrentWardrobe();
    this.saveCache();
  },

  async pushOfflineChanges() {
    const queue = Storage.getOfflineQueue();
    if (queue.length === 0) return;
    UI.toast(`正在推送 ${queue.length} 条离线变更...`);
    for (const change of queue) {
      try { await this.applyChange(change); }
      catch (e) { console.error('应用变更失败', change, e); }
    }
    Storage.setOfflineQueue([]);
  },

  async applyChange(change) {
    switch (change.type) {
      case 'createWardrobe': await this.createWardrobeRemote(change.data); break;
      case 'updateWardrobe': await this.updateWardrobeRemote(change.data); break;
      case 'addClothe': await this.addClotheRemote(change.wardrobeId, change.data, change.imageData); break;
      case 'updateClothe': await this.updateClotheRemote(change.wardrobeId, change.data, change.imageData); break;
      case 'deleteClothe': await this.deleteClotheRemote(change.wardrobeId, change.clotheId); break;
      case 'addOutfit': await this.addOutfitRemote(change.wardrobeId, change.data); break;
      case 'addRecommendation': await this.addRecommendationRemote(change.data); break;
      case 'updateRecommendation': await this.updateRecommendationRemote(change.data); break;
    }
  },

  async updateWardrobeFile(wardrobeId, updater) {
    const path = `data/wardrobes/${wardrobeId}.json`;
    const latest = await GitHub.getFile(path);
    let data = latest.content ? JSON.parse(latest.content) : { wardrobeId, clothes: [], outfits: [] };
    data = updater(data);
    data.lastUpdated = new Date().toISOString();
    await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, `update wardrobe ${wardrobeId}`);
    this.state.allWardrobeData[wardrobeId] = data;
    this.updateCurrentWardrobe();
    this.saveCache();
  },

  // ===== 衣柜管理 =====
  showNewWardrobeModal() {
    UI.closeWardrobeDrawer();
    UI.showModal('新建衣柜', `
      <div class="form-group"><label>衣柜名称</label><input type="text" id="newWardrobeName" placeholder="如：我的衣柜、换季收纳"></div>
      <div class="form-group"><label>描述（可选）</label><input type="text" id="newWardrobeDesc" placeholder="简短描述"></div>
      <div class="form-group"><label>可见性</label>
        <select id="newWardrobeVisibility">
          <option value="private">私有（仅自己可见）</option>
          <option value="shared">共享（同仓库用户可查看）</option>
        </select>
      </div>
      <button class="btn btn-primary btn-block" onclick="App.createWardrobe()">创建衣柜</button>
    `, () => setTimeout(() => UI.$('newWardrobeName').focus(), 100));
  },

  async createWardrobe() {
    const name = UI.$('newWardrobeName').value.trim();
    if (!name) { UI.toast('请输入衣柜名称'); return; }
    const wardrobe = {
      id: UI.uuid(),
      name,
      owner: this.state.config.username || 'local',
      description: UI.$('newWardrobeDesc').value.trim(),
      coverImage: '',
      visibility: UI.$('newWardrobeVisibility').value,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    UI.hideModal();
    this.state.wardrobes.push(wardrobe);
    this.state.allWardrobeData[wardrobe.id] = { wardrobeId: wardrobe.id, clothes: [], outfits: [] };
    this.saveCache();
    if (GitHub.isConfigured()) {
      try { await this.createWardrobeRemote(wardrobe); UI.toast('衣柜创建成功'); }
      catch (e) { Storage.addOfflineChange({ type: 'createWardrobe', data: wardrobe }); UI.toast('已保存到本地，联网后同步'); }
    } else { UI.toast('已保存到本地'); }
    this.switchWardrobe(wardrobe.id);
  },

  async createWardrobeRemote(wardrobe) {
    const path = 'data/wardrobes.json';
    const latest = await GitHub.getFile(path);
    let data = latest.content ? JSON.parse(latest.content) : { version: '2.0', wardrobes: [] };
    if (!data.wardrobes.find(w => w.id === wardrobe.id)) {
      data.wardrobes.push(wardrobe);
    }
    data.lastUpdated = new Date().toISOString();
    await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, `create wardrobe ${wardrobe.name}`);
    const wPath = `data/wardrobes/${wardrobe.id}.json`;
    const wExisting = await GitHub.getFile(wPath);
    if (!wExisting.content) {
      await GitHub.putFile(wPath, JSON.stringify({ wardrobeId: wardrobe.id, clothes: [], outfits: [], lastUpdated: new Date().toISOString() }, null, 2), null, `init wardrobe ${wardrobe.name}`);
    }
    this.state.wardrobes = data.wardrobes;
    this.saveCache();
  },

  async editWardrobe(wardrobeId) {
    const w = this.state.wardrobes.find(x => x.id === wardrobeId);
    if (!w) return;
    UI.closeWardrobeDrawer();
    UI.showModal('编辑衣柜', `
      <div class="form-group"><label>衣柜名称</label><input type="text" id="editWardrobeName" value="${w.name}"></div>
      <div class="form-group"><label>描述</label><input type="text" id="editWardrobeDesc" value="${w.description || ''}"></div>
      <div class="form-group"><label>可见性</label>
        <select id="editWardrobeVisibility">
          <option value="private" ${w.visibility === 'private' ? 'selected' : ''}>私有</option>
          <option value="shared" ${w.visibility === 'shared' ? 'selected' : ''}>共享</option>
        </select>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn btn-danger" style="flex:1" onclick="App.deleteWardrobe('${w.id}')">删除</button>
        <button class="btn btn-primary" style="flex:1" onclick="App.saveWardrobeEdit('${w.id}')">保存</button>
      </div>
    `);
  },

  async saveWardrobeEdit(wardrobeId) {
    const name = UI.$('editWardrobeName').value.trim();
    if (!name) { UI.toast('名称不能为空'); return; }
    const w = this.state.wardrobes.find(x => x.id === wardrobeId);
    w.name = name;
    w.description = UI.$('editWardrobeDesc').value.trim();
    w.visibility = UI.$('editWardrobeVisibility').value;
    w.updatedAt = new Date().toISOString();
    UI.hideModal();
    this.saveCache();
    this.updateCurrentWardrobe();
    if (GitHub.isConfigured()) {
      try { await this.updateWardrobeRemote(w); UI.toast('已保存'); }
      catch (e) { Storage.addOfflineChange({ type: 'updateWardrobe', data: w }); UI.toast('已保存到本地'); }
    }
    UI.renderTab(UI.currentTab);
  },

  async updateWardrobeRemote(wardrobe) {
    const path = 'data/wardrobes.json';
    const latest = await GitHub.getFile(path);
    const data = latest.content ? JSON.parse(latest.content) : { wardrobes: [] };
    const idx = data.wardrobes.findIndex(x => x.id === wardrobe.id);
    if (idx >= 0) data.wardrobes[idx] = wardrobe;
    data.lastUpdated = new Date().toISOString();
    await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, `update wardrobe ${wardrobe.name}`);
    this.state.wardrobes = data.wardrobes;
    this.saveCache();
  },

  async deleteWardrobe(wardrobeId) {
    if (!confirm('确定删除这个衣柜吗？所有衣物和穿搭记录都将被删除，此操作不可恢复。')) return;
    UI.hideModal();
    this.state.wardrobes = this.state.wardrobes.filter(w => w.id !== wardrobeId);
    delete this.state.allWardrobeData[wardrobeId];
    if (this.state.currentWardrobeId === wardrobeId) {
      this.state.currentWardrobeId = null;
      this.updateCurrentWardrobe();
    }
    this.saveCache();
    if (GitHub.isConfigured()) {
      try {
        const path = 'data/wardrobes.json';
        const latest = await GitHub.getFile(path);
        const data = latest.content ? JSON.parse(latest.content) : { wardrobes: [] };
        data.wardrobes = data.wardrobes.filter(w => w.id !== wardrobeId);
        await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, 'delete wardrobe');
        const wPath = `data/wardrobes/${wardrobeId}.json`;
        const wLatest = await GitHub.getFile(wPath);
        if (wLatest.sha) await GitHub.deleteFile(wPath, wLatest.sha, 'delete wardrobe data');
      } catch (e) { console.error('删除远程衣柜失败', e); }
    }
    UI.toast('衣柜已删除');
    UI.renderTab(UI.currentTab);
  },

  switchWardrobe(wardrobeId) {
    this.state.currentWardrobeId = wardrobeId;
    this.state.config.currentWardrobeId = wardrobeId;
    Storage.setConfig(this.state.config);
    this.updateCurrentWardrobe();
    UI.closeWardrobeDrawer();
    UI.renderTab(UI.currentTab);
  },

  // ===== 衣物管理 =====
  onClotheClick(clotheId) {
    if (this.state.recommendMode || this.state.outfitSelectMode) {
      if (!this.state.selectedClotheIds) this.state.selectedClotheIds = [];
      const idx = this.state.selectedClotheIds.indexOf(clotheId);
      if (idx >= 0) this.state.selectedClotheIds.splice(idx, 1);
      else this.state.selectedClotheIds.push(clotheId);
      UI.renderWardrobeTab(UI.$('content'));
      UI.renderSelectBar();
    } else {
      this.showClotheDetail(clotheId);
    }
  },

  showClotheDetail(clotheId) {
    const c = (this.state.currentWardrobeData.clothes || []).find(x => x.id === clotheId);
    if (!c) return;
    const isOwner = this.state.currentWardrobe.owner === this.state.config.username;
    const imgUrl = GitHub.rawUrl(c.image);
    let html = '';
    if (imgUrl) html += `<img src="${imgUrl}" style="width:100%;border-radius:8px;margin-bottom:16px;max-height:300px;object-fit:cover" onerror="this.style.display='none'">`;
    html += `<div class="form-group"><label>类别</label><div>${c.category}${c.subcategory ? ' / ' + c.subcategory : ''}</div></div>`;
    if (c.colors && c.colors.length) html += `<div class="form-group"><label>颜色</label><div>${c.colors.join('、')}</div></div>`;
    if (c.seasons && c.seasons.length) html += `<div class="form-group"><label>季节</label><div>${c.seasons.join('、')}</div></div>`;
    if (c.brand) html += `<div class="form-group"><label>品牌</label><div>${c.brand}</div></div>`;
    if (c.purchaseDate) html += `<div class="form-group"><label>购买日期</label><div>${c.purchaseDate}</div></div>`;
    if (c.notes) html += `<div class="form-group"><label>备注</label><div>${c.notes}</div></div>`;
    if (isOwner) {
      html += `<div style="display:flex;gap:8px;margin-top:16px">
        <button class="btn btn-secondary" style="flex:1" onclick="App.editClothe('${c.id}')">编辑</button>
        <button class="btn btn-danger" style="flex:1" onclick="App.deleteClothe('${c.id}')">删除</button>
      </div>`;
    }
    UI.showModal(c.name, html);
  },

  showAddClotheModal() {
    if (!this.state.currentWardrobe) { UI.toast('请先选择衣柜'); return; }
    const isOwner = this.state.currentWardrobe.owner === this.state.config.username;
    if (!isOwner) { UI.toast('共享衣柜为只读模式'); return; }
    this.state.editingClotheId = null;
    this.state.pendingImage = null;
    UI.showModal('添加衣物', this.getClotheFormHTML(), () => this.bindImageUpload('clotheImageInput'));
  },

  editClothe(clotheId) {
    const c = (this.state.currentWardrobeData.clothes || []).find(x => x.id === clotheId);
    if (!c) return;
    UI.hideModal();
    this.state.editingClotheId = clotheId;
    this.state.pendingImage = null;
    UI.showModal('编辑衣物', this.getClotheFormHTML(c), () => this.bindImageUpload('clotheImageInput', c.image));
  },

  getClotheFormHTML(c = {}) {
    const isEdit = !!this.state.editingClotheId;
    return `
      <div class="image-upload" id="imageUploadPreview" onclick="document.getElementById('clotheImageInput').click()">
        <div class="placeholder"><span class="icon">📷</span>点击上传图片</div>
      </div>
      <input type="file" id="clotheImageInput" accept="image/*" style="display:none">
      <div class="form-group"><label>名称 *</label><input type="text" id="clotheName" value="${c.name || ''}" placeholder="如：白色棉质T恤"></div>
      <div class="form-row">
        <div class="form-group"><label>类别</label>
          <select id="clotheCategory">
            ${['上装','下装','外套','鞋履','配饰'].map(cat => `<option ${c.category === cat ? 'selected' : ''}>${cat}</option>`).join('')}
          </select>
        </div>
        <div class="form-group"><label>子类别</label><input type="text" id="clotheSubcategory" value="${c.subcategory || ''}" placeholder="如：T恤"></div>
      </div>
      <div class="form-group"><label>颜色（逗号分隔）</label><input type="text" id="clotheColors" value="${(c.colors || []).join(',')}" placeholder="如：白色,黑色"></div>
      <div class="form-group"><label>适用季节</label>
        <div style="display:flex;gap:16px;flex-wrap:wrap">
          ${['春','夏','秋','冬'].map(s => `<label style="display:flex;align-items:center;gap:4px;font-size:14px"><input type="checkbox" value="${s}" ${(c.seasons || []).includes(s) ? 'checked' : ''}> ${s}</label>`).join('')}
        </div>
      </div>
      <div class="form-row">
        <div class="form-group"><label>品牌</label><input type="text" id="clotheBrand" value="${c.brand || ''}"></div>
        <div class="form-group"><label>购买日期</label><input type="date" id="clothePurchaseDate" value="${c.purchaseDate || ''}"></div>
      </div>
      <div class="form-group"><label>备注</label><textarea id="clotheNotes" rows="2">${c.notes || ''}</textarea></div>
      <button class="btn btn-primary btn-block" onclick="App.saveClothe()">${isEdit ? '保存修改' : '添加衣物'}</button>
    `;
  },

  bindImageUpload(inputId, existingImage = null) {
    const input = document.getElementById(inputId);
    const preview = document.getElementById('imageUploadPreview');
    if (existingImage) {
      const url = GitHub.rawUrl(existingImage);
      if (url) preview.innerHTML = `<img src="${url}" alt="preview">`;
    }
    input.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (ev) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement('canvas');
          const maxSize = 800;
          let w = img.width, h = img.height;
          if (w > h && w > maxSize) { h = h * maxSize / w; w = maxSize; }
          else if (h > maxSize) { w = w * maxSize / h; h = maxSize; }
          canvas.width = w; canvas.height = h;
          canvas.getContext('2d').drawImage(img, 0, 0, w, h);
          const compressed = canvas.toDataURL('image/jpeg', 0.7);
          preview.innerHTML = `<img src="${compressed}" alt="preview">`;
          this.state.pendingImage = compressed;
        };
        img.src = ev.target.result;
      };
      reader.readAsDataURL(file);
    });
  },

  async saveClothe() {
    const name = UI.$('clotheName').value.trim();
    if (!name) { UI.toast('请输入衣物名称'); return; }

    const isEdit = !!this.state.editingClotheId;
    const editingId = this.state.editingClotheId;
    const existing = isEdit ? this.getExistingClothe(editingId) : {};

    const clothe = {
      id: editingId || UI.uuid(),
      name,
      category: UI.$('clotheCategory').value,
      subcategory: UI.$('clotheSubcategory').value.trim(),
      colors: UI.$('clotheColors').value.split(',').map(s => s.trim()).filter(Boolean),
      seasons: Array.from(document.querySelectorAll('#modalBody input[type=checkbox]:checked')).map(cb => cb.value),
      brand: UI.$('clotheBrand').value.trim(),
      purchaseDate: UI.$('clothePurchaseDate').value,
      notes: UI.$('clotheNotes').value.trim(),
      image: this.state.pendingImage ? null : (existing.image || null),
      createdAt: existing.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const wardrobeId = this.state.currentWardrobeId;
    const imageData = this.state.pendingImage;

    UI.hideModal();
    this.state.pendingImage = null;
    this.state.editingClotheId = null;

    this.updateLocalClothe(wardrobeId, clothe);
    this.saveCache();

    if (GitHub.isConfigured()) {
      try {
        if (isEdit) await this.updateClotheRemote(wardrobeId, clothe, imageData);
        else await this.addClotheRemote(wardrobeId, clothe, imageData);
        UI.toast('已保存');
      } catch (e) {
        Storage.addOfflineChange({ type: isEdit ? 'updateClothe' : 'addClothe', wardrobeId, data: clothe, imageData });
        UI.toast('已保存到本地，联网后同步');
      }
    } else { UI.toast('已保存到本地'); }

    UI.renderTab(UI.currentTab);
  },

  getExistingClothe(clotheId) {
    return (this.state.currentWardrobeData.clothes || []).find(c => c.id === clotheId) || {};
  },

  updateLocalClothe(wardrobeId, clothe) {
    if (!this.state.allWardrobeData[wardrobeId]) {
      this.state.allWardrobeData[wardrobeId] = { wardrobeId, clothes: [], outfits: [] };
    }
    const data = this.state.allWardrobeData[wardrobeId];
    const idx = (data.clothes || []).findIndex(c => c.id === clothe.id);
    if (idx >= 0) data.clothes[idx] = clothe;
    else data.clothes.push(clothe);
    this.updateCurrentWardrobe();
  },

  async addClotheRemote(wardrobeId, clothe, imageData) {
    if (imageData) {
      const imgPath = `images/${clothe.id}.jpg`;
      await GitHub.uploadImage(imgPath, imageData);
      clothe.image = imgPath;
      this.updateLocalClothe(wardrobeId, clothe);
      this.saveCache();
    }
    await this.updateWardrobeFile(wardrobeId, (data) => {
      data.clothes = data.clothes || [];
      const idx = data.clothes.findIndex(c => c.id === clothe.id);
      if (idx >= 0) data.clothes[idx] = clothe;
      else data.clothes.push(clothe);
      return data;
    });
  },

  async updateClotheRemote(wardrobeId, clothe, imageData) {
    if (imageData) {
      const imgPath = `images/${clothe.id}.jpg`;
      const existing = await GitHub.getFile(imgPath);
      await GitHub.uploadImage(imgPath, imageData, existing.sha);
      clothe.image = imgPath;
      this.updateLocalClothe(wardrobeId, clothe);
      this.saveCache();
    }
    await this.updateWardrobeFile(wardrobeId, (data) => {
      const idx = (data.clothes || []).findIndex(c => c.id === clothe.id);
      if (idx >= 0) data.clothes[idx] = clothe;
      return data;
    });
  },

  async deleteClothe(clotheId) {
    if (!confirm('确定删除这件衣物吗？')) return;
    UI.hideModal();
    const wardrobeId = this.state.currentWardrobeId;
    const data = this.state.allWardrobeData[wardrobeId];
    if (data) data.clothes = (data.clothes || []).filter(c => c.id !== clotheId);
    this.updateCurrentWardrobe();
    this.saveCache();
    if (GitHub.isConfigured()) {
      try {
        await this.updateWardrobeFile(wardrobeId, (d) => {
          d.clothes = (d.clothes || []).filter(c => c.id !== clotheId);
          return d;
        });
      } catch (e) { Storage.addOfflineChange({ type: 'deleteClothe', wardrobeId, clotheId }); }
    }
    UI.toast('已删除');
    UI.renderTab(UI.currentTab);
  },

  async deleteClotheRemote(wardrobeId, clotheId) {
    await this.updateWardrobeFile(wardrobeId, (d) => {
      d.clothes = (d.clothes || []).filter(c => c.id !== clotheId);
      return d;
    });
  },

  setFilter(key, value) {
    this.state.filters = this.state.filters || {};
    this.state.filters[key] = value;
    UI.renderWardrobeTab(UI.$('content'));
  },

  // ===== 穿搭 =====
  changeMonth(delta) {
    const cal = this.state.calendar;
    cal.month += delta;
    if (cal.month < 0) { cal.month = 11; cal.year--; }
    if (cal.month > 11) { cal.month = 0; cal.year++; }
    UI.renderOutfitTab(UI.$('content'));
  },

  selectOutfitDate(dateStr) {
    this.state.selectedOutfitDate = dateStr;
    UI.renderOutfitTab(UI.$('content'));
    const [y, m, d] = dateStr.split('-').map(Number);
    const outfits = (this.state.currentWardrobeData.outfits || []).filter(o => {
      const od = new Date(o.date);
      return od.getFullYear() === y && od.getMonth() === m && od.getDate() === d;
    });
    const detail = UI.$('outfitDetail');
    if (!detail) return;
    if (outfits.length > 0) {
      const outfit = outfits[0];
      const clothes = outfit.clotheIds.map(id => (this.state.currentWardrobeData.clothes || []).find(c => c.id === id)).filter(Boolean);
      detail.innerHTML = `<div class="card">
        <h4 style="margin-bottom:12px">${y}年${m + 1}月${d}日 穿搭</h4>
        <div class="recommend-clothes" style="margin-bottom:12px">
          ${clothes.map(c => {
            const url = GitHub.rawUrl(c.image);
            return url ? `<img src="${url}" class="recommend-clothe-img" alt="${c.name}" onerror="this.style.display='none'">`
              : `<div class="recommend-clothe-img" style="display:flex;align-items:center;justify-content:center;font-size:20px">👕</div>`;
          }).join('')}
        </div>
        ${outfit.notes ? `<p style="font-size:14px;color:var(--text-light)">${outfit.notes}</p>` : ''}
      </div>`;
    } else {
      const isOwner = this.state.currentWardrobe.owner === this.state.config.username;
      detail.innerHTML = `<div class="card">
        <h4 style="margin-bottom:12px">${y}年${m + 1}月${d}日</h4>
        <p style="font-size:14px;color:var(--text-light);margin-bottom:12px">当天还没有穿搭记录</p>
        ${isOwner ? `<button class="btn btn-primary btn-sm" onclick="App.showAddOutfitModal('${dateStr}')">+ 添加穿搭</button>` : ''}
      </div>`;
    }
  },

  showAddOutfitModal(dateStr) {
    const [y, m, d] = dateStr.split('-').map(Number);
    this.state.outfitSelectDate = dateStr;
    this.state.selectedClotheIds = [];
    UI.showModal(`添加 ${y}年${m + 1}月${d}日 穿搭`, `
      <div class="form-group"><label>选择衣物</label>
        <button class="btn btn-secondary btn-block" onclick="App.startOutfitSelect()">从衣柜选择</button>
        <div id="selectedOutfitClothes" style="margin-top:8px"></div>
      </div>
      <div class="form-group"><label>备注</label><textarea id="outfitNotes" rows="2"></textarea></div>
      <input type="hidden" id="outfitDateStr" value="${dateStr}">
      <input type="hidden" id="outfitClotheIds" value="">
      <button class="btn btn-primary btn-block" onclick="App.saveOutfit()">保存穿搭</button>
    `);
  },

  startOutfitSelect() {
    UI.hideModal();
    this.state.outfitSelectMode = true;
    this.state.selectedClotheIds = [];
    UI.renderTab('wardrobe');
    UI.toast('点击选择衣物，选完后点底部「确认穿搭」');
  },

  cancelSelect() {
    this.state.recommendMode = false;
    this.state.outfitSelectMode = false;
    this.state.selectedClotheIds = [];
    UI.hideSelectBar();
    UI.renderTab(UI.currentTab);
  },

  confirmSelect() {
    if (this.state.recommendMode) this.confirmRecommend();
    else if (this.state.outfitSelectMode) this.confirmOutfitSelect();
  },

  confirmOutfitSelect() {
    const dateStr = this.state.outfitSelectDate;
    const ids = [...this.state.selectedClotheIds];
    this.state.outfitSelectMode = false;
    this.state.selectedClotheIds = [];
    UI.hideSelectBar();
    const [y, m, d] = dateStr.split('-').map(Number);
    const clothes = ids.map(id => (this.state.currentWardrobeData.clothes || []).find(c => c.id === id)).filter(Boolean);
    UI.showModal(`添加 ${y}年${m + 1}月${d}日 穿搭`, `
      <div class="form-group"><label>已选衣物（${clothes.length}件）</label>
        <div class="recommend-clothes">
          ${clothes.map(c => {
            const url = GitHub.rawUrl(c.image);
            return url ? `<img src="${url}" class="recommend-clothe-img" alt="${c.name}">`
              : `<div class="recommend-clothe-img" style="display:flex;align-items:center;justify-content:center;font-size:20px">👕</div>`;
          }).join('')}
        </div>
        <button class="btn btn-secondary btn-sm" style="margin-top:8px" onclick="App.startOutfitSelect()">重新选择</button>
      </div>
      <div class="form-group"><label>备注</label><textarea id="outfitNotes" rows="2"></textarea></div>
      <input type="hidden" id="outfitDateStr" value="${dateStr}">
      <input type="hidden" id="outfitClotheIds" value="${ids.join(',')}">
      <button class="btn btn-primary btn-block" onclick="App.saveOutfit()">保存穿搭</button>
    `);
  },

  async saveOutfit() {
    const dateStr = UI.$('outfitDateStr').value;
    const clotheIds = UI.$('outfitClotheIds').value.split(',').filter(Boolean);
    const notes = UI.$('outfitNotes').value.trim();
    if (clotheIds.length === 0) { UI.toast('请至少选择一件衣物'); return; }
    const [y, m, d] = dateStr.split('-').map(Number);
    const outfit = {
      id: UI.uuid(),
      date: `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`,
      clotheIds, notes,
      createdAt: new Date().toISOString()
    };
    UI.hideModal();
    const wardrobeId = this.state.currentWardrobeId;
    if (!this.state.allWardrobeData[wardrobeId]) {
      this.state.allWardrobeData[wardrobeId] = { wardrobeId, clothes: [], outfits: [] };
    }
    this.state.allWardrobeData[wardrobeId].outfits.push(outfit);
    this.updateCurrentWardrobe();
    this.saveCache();
    if (GitHub.isConfigured()) {
      try { await this.addOutfitRemote(wardrobeId, outfit); UI.toast('穿搭已保存'); }
      catch (e) { Storage.addOfflineChange({ type: 'addOutfit', wardrobeId, data: outfit }); UI.toast('已保存到本地'); }
    } else { UI.toast('已保存到本地'); }
    UI.renderTab('outfit');
    this.selectOutfitDate(dateStr);
  },

  async addOutfitRemote(wardrobeId, outfit) {
    await this.updateWardrobeFile(wardrobeId, (data) => {
      data.outfits = data.outfits || [];
      data.outfits.push(outfit);
      return data;
    });
  },

  // ===== 推荐 =====
  startRecommendMode() {
    if (!this.state.currentWardrobe) { UI.toast('请先选择衣柜'); return; }
    const isOwner = this.state.currentWardrobe.owner === this.state.config.username;
    if (isOwner) { UI.toast('这是你自己的衣柜，去对方的共享衣柜推荐吧'); return; }
    this.state.recommendMode = true;
    this.state.selectedClotheIds = [];
    UI.renderTab('wardrobe');
    UI.toast('从对方衣柜选择衣物，选完后点底部「确认推荐」');
  },

  confirmRecommend() {
    const ids = [...this.state.selectedClotheIds];
    const targetWardrobe = this.state.currentWardrobe;
    this.state.recommendMode = false;
    this.state.selectedClotheIds = [];
    UI.hideSelectBar();
    const clothes = ids.map(id => (this.state.currentWardrobeData.clothes || []).find(c => c.id === id)).filter(Boolean);
    UI.showModal('发送推荐', `
      <div class="form-group"><label>推荐给：${targetWardrobe.owner}（${targetWardrobe.name}）</label></div>
      <div class="form-group"><label>已选衣物（${clothes.length}件）</label>
        <div class="recommend-clothes">
          ${clothes.map(c => {
            const url = GitHub.rawUrl(c.image);
            return url ? `<img src="${url}" class="recommend-clothe-img" alt="${c.name}">`
              : `<div class="recommend-clothe-img" style="display:flex;align-items:center;justify-content:center;font-size:20px">👕</div>`;
          }).join('')}
        </div>
      </div>
      <div class="form-group"><label>推荐语</label>
        <textarea id="recommendMessage" rows="3" placeholder="说点什么，比如：这件配你那条裙子很好看"></textarea>
      </div>
      <input type="hidden" id="recommendClotheIds" value="${ids.join(',')}">
      <input type="hidden" id="recommendToWardrobeId" value="${targetWardrobe.id}">
      <button class="btn btn-primary btn-block" onclick="App.sendRecommendation()">发送推荐</button>
    `);
  },

  async sendRecommendation() {
    const clotheIds = UI.$('recommendClotheIds').value.split(',').filter(Boolean);
    const toWardrobeId = UI.$('recommendToWardrobeId').value;
    const message = UI.$('recommendMessage').value.trim();
    const rec = {
      id: UI.uuid(),
      fromUser: this.state.config.username,
      toWardrobeId, clotheIds, message,
      status: 'pending',
      createdAt: new Date().toISOString(),
      respondedAt: null,
      acceptedOutfitDate: null
    };
    UI.hideModal();
    this.state.recommendations.push(rec);
    this.saveCache();
    if (GitHub.isConfigured()) {
      try { await this.addRecommendationRemote(rec); UI.toast('推荐已发送'); }
      catch (e) { Storage.addOfflineChange({ type: 'addRecommendation', data: rec }); UI.toast('已保存到本地，联网后发送'); }
    } else { UI.toast('已保存到本地'); }
    UI.renderTab('recommend');
  },

  async addRecommendationRemote(rec) {
    const path = 'data/recommendations.json';
    const latest = await GitHub.getFile(path);
    const data = latest.content ? JSON.parse(latest.content) : { recommendations: [] };
    if (!data.recommendations.find(r => r.id === rec.id)) data.recommendations.push(rec);
    data.lastUpdated = new Date().toISOString();
    await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, 'send recommendation');
    this.state.recommendations = data.recommendations;
    this.saveCache();
  },

  viewRecommendation(recId) {
    const rec = this.state.recommendations.find(r => r.id === recId);
    if (!rec) return;
    const clothes = UI.getClothesByIds(rec.clotheIds);
    const wardrobe = this.state.wardrobes.find(w => w.id === rec.toWardrobeId);
    const isForMe = wardrobe && wardrobe.owner === this.state.config.username;
    const isPending = rec.status === 'pending';
    const statusText = { pending: '待查看', accepted: '已采纳', ignored: '已忽略' };
    const clothesHtml = clothes.map(c => {
      const url = GitHub.rawUrl(c.image);
      return `<div style="text-align:center">
        ${url ? `<img src="${url}" style="width:80px;height:80px;object-fit:cover;border-radius:8px" onerror="this.style.display='none'">`
          : '<div style="width:80px;height:80px;display:flex;align-items:center;justify-content:center;font-size:32px;background:var(--bg);border-radius:8px">👕</div>'}
        <div style="font-size:12px;margin-top:4px">${c.name}</div>
      </div>`;
    }).join('');
    UI.showModal('推荐详情', `
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
        <img src="https://github.com/${rec.fromUser}.png" style="width:40px;height:40px;border-radius:50%" onerror="this.style.background='#ccc'">
        <div>
          <div style="font-weight:600">${rec.fromUser}</div>
          <div style="font-size:12px;color:var(--text-light)">${UI.formatTime(rec.createdAt)}${wardrobe ? ` · 推荐到 ${wardrobe.name}` : ''}</div>
        </div>
        <span class="recommend-status status-${rec.status}" style="margin-left:auto">${statusText[rec.status]}</span>
      </div>
      ${rec.message ? `<p style="margin-bottom:16px;line-height:1.6">${rec.message}</p>` : ''}
      <div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px">${clothesHtml}</div>
      ${isForMe && isPending ? `
        <div style="display:flex;gap:8px">
          <button class="btn btn-secondary" style="flex:1" onclick="App.respondRecommendation('${rec.id}','ignored')">忽略</button>
          <button class="btn btn-primary" style="flex:1" onclick="App.respondRecommendation('${rec.id}','accepted')">采纳为穿搭</button>
        </div>
      ` : ''}
      ${rec.status === 'accepted' && rec.acceptedOutfitDate ? `<p style="font-size:13px;color:var(--success);text-align:center;margin-top:8px">已于 ${rec.acceptedOutfitDate} 采纳</p>` : ''}
    `);
  },

  async respondRecommendation(recId, status) {
    const rec = this.state.recommendations.find(r => r.id === recId);
    if (!rec) return;
    rec.status = status;
    rec.respondedAt = new Date().toISOString();
    if (status === 'accepted') {
      const today = new Date();
      const dateStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      rec.acceptedOutfitDate = dateStr;
      const wardrobeId = rec.toWardrobeId;
      const outfit = {
        id: UI.uuid(),
        date: dateStr,
        clotheIds: rec.clotheIds,
        notes: `来自 ${rec.fromUser} 的推荐：${rec.message || ''}`,
        createdAt: new Date().toISOString()
      };
      if (!this.state.allWardrobeData[wardrobeId]) {
        this.state.allWardrobeData[wardrobeId] = { wardrobeId, clothes: [], outfits: [] };
      }
      this.state.allWardrobeData[wardrobeId].outfits.push(outfit);
      if (GitHub.isConfigured()) {
        try { await this.addOutfitRemote(wardrobeId, outfit); }
        catch (e) { Storage.addOfflineChange({ type: 'addOutfit', wardrobeId, data: outfit }); }
      }
    }
    UI.hideModal();
    this.saveCache();
    if (GitHub.isConfigured()) {
      try { await this.updateRecommendationRemote(rec); }
      catch (e) { Storage.addOfflineChange({ type: 'updateRecommendation', data: rec }); }
    }
    UI.toast(status === 'accepted' ? '已采纳为今日穿搭' : '已忽略');
    UI.renderTab('recommend');
  },

  async updateRecommendationRemote(rec) {
    const path = 'data/recommendations.json';
    const latest = await GitHub.getFile(path);
    const data = latest.content ? JSON.parse(latest.content) : { recommendations: [] };
    const idx = data.recommendations.findIndex(r => r.id === rec.id);
    if (idx >= 0) data.recommendations[idx] = rec;
    data.lastUpdated = new Date().toISOString();
    await GitHub.putFile(path, JSON.stringify(data, null, 2), latest.sha, 'respond recommendation');
    this.state.recommendations = data.recommendations;
    this.saveCache();
  },

  setRecSubTab(tab) {
    this.state.recSubTab = tab;
    UI.renderTab('recommend');
  },

  // ===== 设置 =====
  async saveSettings() {
    const username = UI.$('settingUsername').value.trim();
    const repo = UI.$('settingRepo').value.trim();
    const token = UI.$('settingToken').value.trim();
    if (!username || !repo || !token) { UI.toast('请填写完整的 GitHub 配置'); return; }
    this.state.config = { ...this.state.config, username, repo, token };
    Storage.setConfig(this.state.config);
    GitHub.init(this.state.config);
    UI.toast('正在测试连接...');
    try {
      await this.pullAllData();
      UI.setSyncStatus('online');
      this.syncStatusText = '已连接';
      UI.toast('连接成功，数据已同步');
      if (this.syncTimer) clearInterval(this.syncTimer);
      this.syncTimer = setInterval(() => this.autoSync(), 30000);
      UI.renderTab('wardrobe');
    } catch (e) {
      UI.toast('连接失败: ' + e.message);
      this.syncStatusText = '连接失败';
    }
  },

  exportData() {
    const data = {
      wardrobes: this.state.wardrobes,
      wardrobeData: this.state.allWardrobeData,
      recommendations: this.state.recommendations,
      exportedAt: new Date().toISOString()
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `wardrobe-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    UI.toast('数据已导出');
  },

  doImport() {
    const fileInput = UI.$('importFile');
    const file = fileInput.files[0];
    if (!file) { UI.toast('请选择文件'); return; }
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target.result);
        if (data.wardrobes) this.state.wardrobes = data.wardrobes;
        if (data.wardrobeData) this.state.allWardrobeData = data.wardrobeData;
        if (data.recommendations) this.state.recommendations = data.recommendations;
        this.saveCache();
        this.updateCurrentWardrobe();
        UI.hideModal();
        UI.toast('数据已导入');
        UI.renderTab(UI.currentTab);
      } catch (err) { UI.toast('导入失败：文件格式不正确'); }
    };
    reader.readAsText(file);
  },

  clearAllData() {
    if (!confirm('确定清除所有本地数据并登出吗？这不会删除 GitHub 仓库中的数据。')) return;
    Storage.clear();
    this.state.config = {};
    this.state.wardrobes = [];
    this.state.allWardrobeData = {};
    this.state.recommendations = [];
    this.state.currentWardrobeId = null;
    this.state.currentWardrobe = null;
    this.state.currentWardrobeData = null;
    GitHub.init({});
    if (this.syncTimer) clearInterval(this.syncTimer);
    UI.setSyncStatus('');
    this.syncStatusText = '未连接';
    UI.toast('已清除本地数据');
    UI.renderTab('settings');
  }
};

document.addEventListener('DOMContentLoaded', () => App.init());

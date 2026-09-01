const UI = {
  currentTab: 'wardrobe',
  charts: {},

  $(id) { return document.getElementById(id); },

  toast(message, duration = 2500) {
    const toast = this.$('toast');
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => toast.classList.remove('show'), duration);
  },

  showModal(title, bodyHTML, onOpen) {
    this.$('modalTitle').textContent = title;
    this.$('modalBody').innerHTML = bodyHTML;
    this.$('modalOverlay').classList.add('show');
    if (onOpen) setTimeout(onOpen, 50);
  },

  hideModal() { this.$('modalOverlay').classList.remove('show'); },

  uuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
      const r = Math.random() * 16 | 0;
      return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
  },

  setSyncStatus(status) {
    const dot = this.$('syncStatus').querySelector('.sync-dot');
    dot.className = 'sync-dot ' + status;
  },

  renderTab(tab) {
    this.currentTab = tab;
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    const fab = this.$('addClotheFab');
    if (fab) fab.style.display = 'none';
    this.hideSelectBar();
    const recFab = document.getElementById('recommendFab');
    if (recFab) recFab.remove();

    const content = this.$('content');
    switch (tab) {
      case 'wardrobe': this.renderWardrobeTab(content); break;
      case 'outfit': this.renderOutfitTab(content); break;
      case 'recommend': this.renderRecommendTab(content); break;
      case 'stats': this.renderStatsTab(content); break;
      case 'settings': this.renderSettingsTab(content); break;
    }
  },

  renderWardrobeTab(content) {
    const state = App.state;
    if (!state.currentWardrobe) {
      content.innerHTML = `<div class="empty-state">
        <div class="icon">👔</div>
        <div class="text">还没有选择衣柜</div>
        <button class="btn btn-primary" onclick="UI.openWardrobeDrawer()">选择或创建衣柜</button>
      </div>`;
      return;
    }
    const isOwner = state.currentWardrobe.owner === state.config.username;
    const readonly = !isOwner;
    const filters = state.filters || {};
    let html = '';
    if (readonly) html += `<div class="readonly-banner">📖 共享衣柜（只读）— 所有者：${state.currentWardrobe.owner}</div>`;
    if (state.recommendMode) html += `<div class="readonly-banner" style="background:#D4EDDA;color:#155724">✨ 推荐模式：点击选择衣物，选完后点底部「确认推荐」</div>`;
    else if (state.outfitSelectMode) html += `<div class="readonly-banner" style="background:#D4EDDA;color:#155724">✨ 穿搭选择：点击选择衣物，选完后点底部「确认穿搭」</div>`;
    html += `<div class="search-bar"><input type="text" class="search-input" id="searchInput" placeholder="搜索衣物..." value="${filters.search || ''}"></div>
      <div class="filter-chips">${this.renderFilterChips(filters)}</div>`;
    const clothes = this.getFilteredClothes();
    if (clothes.length === 0) {
      html += `<div class="empty-state"><div class="icon">🧥</div><div class="text">${filters.search || filters.category ? '没有找到匹配的衣物' : '衣柜还是空的'}</div></div>`;
    } else {
      html += `<div class="clothes-grid">${clothes.map(c => this.renderClotheCard(c)).join('')}</div>`;
    }
    content.innerHTML = html;
    const searchInput = this.$('searchInput');
    if (searchInput) searchInput.addEventListener('input', (e) => {
      App.state.filters = App.state.filters || {};
      App.state.filters.search = e.target.value;
      this.renderWardrobeTab(this.$('content'));
    });
    const fab = this.$('addClotheFab');
    if (fab) {
      if (readonly || state.recommendMode || state.outfitSelectMode) fab.style.display = 'none';
      else { fab.style.display = 'flex'; fab.onclick = () => App.showAddClotheModal(); }
    }
    if (readonly && !state.recommendMode) {
      const recFab = document.createElement('button');
      recFab.className = 'recommend-fab';
      recFab.textContent = '💌 推荐穿搭';
      recFab.onclick = () => App.startRecommendMode();
      recFab.id = 'recommendFab';
      document.body.appendChild(recFab);
    }
    if (state.recommendMode || state.outfitSelectMode) this.renderSelectBar();
  },

  renderFilterChips(filters) {
    const categories = ['全部', '上装', '下装', '外套', '鞋履', '配饰'];
    return categories.map(cat => `<span class="chip ${(filters.category || '全部') === cat ? 'active' : ''}" onclick="App.setFilter('category','${cat}')">${cat}</span>`).join('');
  },

  getFilteredClothes() {
    const state = App.state;
    let clothes = (state.currentWardrobeData && state.currentWardrobeData.clothes) || [];
    const filters = state.filters || {};
    if (filters.search) {
      const q = filters.search.toLowerCase();
      clothes = clothes.filter(c => c.name.toLowerCase().includes(q) || (c.brand && c.brand.toLowerCase().includes(q)) || (c.notes && c.notes.toLowerCase().includes(q)));
    }
    if (filters.category && filters.category !== '全部') clothes = clothes.filter(c => c.category === filters.category);
    return clothes.sort((a, b) => new Date(b.updatedAt || b.createdAt) - new Date(a.updatedAt || a.createdAt));
  },

  renderClotheCard(c) {
    const selected = App.state.selectedClotheIds && App.state.selectedClotheIds.includes(c.id);
    const imgUrl = GitHub.rawUrl(c.image);
    const imgHtml = imgUrl ? `<img src="${imgUrl}" class="clothe-image" alt="${c.name}" onerror="this.outerHTML='<div class=clothe-image>👕</div>'">` : `<div class="clothe-image">👕</div>`;
    return `<div class="clothe-card ${selected ? 'selected' : ''}" onclick="App.onClotheClick('${c.id}')">${imgHtml}
      <div class="clothe-info"><div class="clothe-name">${c.name}</div>
        <div class="clothe-tags"><span class="tag">${c.category}</span>${c.colors && c.colors[0] ? `<span class="tag">${c.colors[0]}</span>` : ''}</div>
      </div></div>`;
  },

  renderOutfitTab(content) {
    const state = App.state;
    if (!state.currentWardrobe) { content.innerHTML = `<div class="empty-state"><div class="icon">📅</div><div class="text">请先选择衣柜</div></div>`; return; }
    const cal = state.calendar || { year: new Date().getFullYear(), month: new Date().getMonth() };
    const outfits = (state.currentWardrobeData && state.currentWardrobeData.outfits) || [];
    content.innerHTML = `<div class="calendar">
      <div class="calendar-header"><button class="calendar-nav" onclick="App.changeMonth(-1)">‹</button><h3>${cal.year}年${cal.month + 1}月</h3><button class="calendar-nav" onclick="App.changeMonth(1)">›</button></div>
      <div class="calendar-grid">${['日','一','二','三','四','五','六'].map(d => `<div class="calendar-day-name">${d}</div>`).join('')}${this.renderCalendarDays(cal, outfits)}</div>
    </div><div id="outfitDetail"></div>`;
  },

  renderCalendarDays(cal, outfits) {
    const firstDay = new Date(cal.year, cal.month, 1);
    const lastDay = new Date(cal.year, cal.month + 1, 0);
    const startWeekday = firstDay.getDay();
    const daysInMonth = lastDay.getDate();
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${today.getMonth()}-${today.getDate()}`;
    let html = '';
    const prevLast = new Date(cal.year, cal.month, 0).getDate();
    for (let i = startWeekday - 1; i >= 0; i--) html += `<div class="calendar-day other-month">${prevLast - i}</div>`;
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${cal.year}-${cal.month}-${d}`;
      const hasOutfit = outfits.some(o => { const od = new Date(o.date); return od.getFullYear() === cal.year && od.getMonth() === cal.month && od.getDate() === d; });
      html += `<div class="calendar-day ${dateStr === todayStr ? 'today' : ''} ${hasOutfit ? 'has-outfit' : ''} ${App.state.selectedOutfitDate === dateStr ? 'selected' : ''}" onclick="App.selectOutfitDate('${dateStr}')">${d}${hasOutfit ? '<span class="outfit-dot"></span>' : ''}</div>`;
    }
    const total = startWeekday + daysInMonth;
    const remaining = (7 - (total % 7)) % 7;
    for (let i = 1; i <= remaining; i++) html += `<div class="calendar-day other-month">${i}</div>`;
    return html;
  },

  renderRecommendTab(content) {
    const state = App.state;
    const subTab = state.recSubTab || 'received';
    if (!state.config.username) { content.innerHTML = `<div class="empty-state"><div class="icon">💌</div><div class="text">请先在设置中配置 GitHub 用户名</div></div>`; return; }
    const allRecs = state.recommendations || [];
    const myWardrobeIds = (state.wardrobes || []).filter(w => w.owner === state.config.username).map(w => w.id);
    let recs = subTab === 'received' ? allRecs.filter(r => myWardrobeIds.includes(r.toWardrobeId)) : allRecs.filter(r => r.fromUser === state.config.username);
    recs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    let html = `<div class="sub-tabs"><div class="sub-tab ${subTab === 'received' ? 'active' : ''}" onclick="App.setRecSubTab('received')">收到的推荐</div><div class="sub-tab ${subTab === 'sent' ? 'active' : ''}" onclick="App.setRecSubTab('sent')">发出的推荐</div></div>`;
    if (recs.length === 0) {
      html += `<div class="empty-state"><div class="icon">💌</div><div class="text">${subTab === 'received' ? '还没有收到推荐' : '还没有发出推荐'}</div><div style="font-size:13px;color:var(--text-light)">去对方的共享衣柜，点击「推荐穿搭」给 TA 推荐吧</div></div>`;
    } else {
      html += recs.map(r => this.renderRecommendCard(r)).join('');
    }
    content.innerHTML = html;
    const unread = allRecs.filter(r => myWardrobeIds.includes(r.toWardrobeId) && r.status === 'pending').length;
    const badge = this.$('recommendBadge');
    if (unread > 0) { badge.style.display = 'flex'; badge.textContent = unread > 99 ? '99+' : unread; } else badge.style.display = 'none';
  },

  renderRecommendCard(r) {
    const wardrobe = (App.state.wardrobes || []).find(w => w.id === r.toWardrobeId);
    const clothes = this.getClothesByIds(r.clotheIds);
    const statusText = { pending: '待查看', accepted: '已采纳', ignored: '已忽略' };
    const clothesHtml = clothes.map(c => {
      const url = GitHub.rawUrl(c.image);
      return url ? `<img src="${url}" class="recommend-clothe-img" alt="${c.name}" onerror="this.style.display='none'">` : `<div class="recommend-clothe-img" style="display:flex;align-items:center;justify-content:center;font-size:24px">👕</div>`;
    }).join('');
    return `<div class="recommend-card" onclick="App.viewRecommendation('${r.id}')">
      <div class="recommend-header"><img src="https://github.com/${r.fromUser}.png" class="recommend-avatar" alt="${r.fromUser}" onerror="this.style.background='#ccc'">
        <div><div class="recommend-user">${r.fromUser}</div><div class="recommend-time">${this.formatTime(r.createdAt)}${wardrobe ? ` · ${wardrobe.name}` : ''}</div></div>
        <span class="recommend-status status-${r.status}">${statusText[r.status]}</span></div>
      ${r.message ? `<div class="recommend-message">${r.message}</div>` : ''}
      <div class="recommend-clothes">${clothesHtml}</div></div>`;
  },

  getClothesByIds(ids) {
    const result = [];
    const all = App.state.allWardrobeData || {};
    ids.forEach(id => { for (const wid in all) { const found = (all[wid].clothes || []).find(c => c.id === id); if (found) { result.push(found); break; } } });
    return result;
  },

  renderStatsTab(content) {
    const state = App.state;
    if (!state.currentWardrobeData) { content.innerHTML = `<div class="empty-state"><div class="icon">📊</div><div class="text">请先选择衣柜</div></div>`; return; }
    const clothes = state.currentWardrobeData.clothes || [];
    const outfits = state.currentWardrobeData.outfits || [];
    const categoryCount = {};
    clothes.forEach(c => { categoryCount[c.category] = (categoryCount[c.category] || 0) + 1; });
    const now = new Date();
    const monthOutfits = outfits.filter(o => { const d = new Date(o.date); return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth(); });
    content.innerHTML = `<div class="stats-grid">
      <div class="stat-card"><div class="stat-value">${clothes.length}</div><div class="stat-label">衣物总数</div></div>
      <div class="stat-card"><div class="stat-value">${outfits.length}</div><div class="stat-label">穿搭记录</div></div>
      <div class="stat-card"><div class="stat-value">${monthOutfits.length}</div><div class="stat-label">本月穿搭</div></div>
      <div class="stat-card"><div class="stat-value">${Object.keys(categoryCount).length}</div><div class="stat-label">类别数</div></div></div>
      <div class="chart-container"><h4>类别分布</h4><canvas id="categoryChart" height="200"></canvas></div>
      <div class="chart-container"><h4>穿搭频率 Top 5</h4><canvas id="topClothesChart" height="200"></canvas></div>`;
    setTimeout(() => this.renderCharts(categoryCount, clothes, outfits), 80);
  },

  renderCharts(categoryCount, clothes, outfits) {
    Object.values(this.charts).forEach(c => c && c.destroy && c.destroy());
    this.charts = {};
    const ctx1 = document.getElementById('categoryChart');
    if (ctx1 && Object.keys(categoryCount).length > 0) {
      this.charts.category = new Chart(ctx1, { type: 'doughnut', data: { labels: Object.keys(categoryCount), datasets: [{ data: Object.values(categoryCount), backgroundColor: ['#B8860B','#D4A84B','#8B7355','#C0392B','#27AE60','#3498DB'] }] }, options: { responsive: true, plugins: { legend: { position: 'right' } } } });
    }
    const wearCount = {};
    outfits.forEach(o => o.clotheIds.forEach(id => { wearCount[id] = (wearCount[id] || 0) + 1; }));
    const top5 = Object.entries(wearCount).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([id, count]) => { const c = clothes.find(x => x.id === id); return { name: c ? c.name : '未知', count }; });
    const ctx2 = document.getElementById('topClothesChart');
    if (ctx2 && top5.length > 0) {
      this.charts.top = new Chart(ctx2, { type: 'bar', data: { labels: top5.map(t => t.name), datasets: [{ label: '穿搭次数', data: top5.map(t => t.count), backgroundColor: '#B8860B' }] }, options: { responsive: true, indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { beginAtZero: true, ticks: { stepSize: 1 } } } } });
    }
  },

  renderSettingsTab(content) {
    const config = App.state.config;
    const offlineQueue = Storage.getOfflineQueue();
    content.innerHTML = `<div class="settings-section"><h4>GitHub 配置</h4>
      <div class="form-group"><label>GitHub 用户名</label><input type="text" id="settingUsername" value="${config.username || ''}" placeholder="你的 GitHub 用户名"></div>
      <div class="form-group"><label>仓库名</label><input type="text" id="settingRepo" value="${config.repo || ''}" placeholder="仓库名称"></div>
      <div class="form-group"><label>Personal Access Token</label><div style="position:relative"><input type="password" id="settingToken" value="${config.token || ''}" placeholder="ghp_xxxxxxxxxxxx"><button class="btn btn-sm btn-secondary" style="position:absolute;right:4px;top:50%;transform:translateY(-50%)" onclick="UI.toggleToken()">显示</button></div>
        <div style="font-size:12px;color:var(--text-light);margin-top:6px">Token 仅保存在本设备，不会上传。需要 repo 权限。<a href="https://github.com/settings/tokens/new?scopes=repo" target="_blank" style="color:var(--primary)">生成 Token</a></div></div>
      <button class="btn btn-primary btn-block" onclick="App.saveSettings()">保存配置并测试连接</button></div>
      <div class="settings-section"><h4>同步</h4>
        <div class="settings-item"><span class="label">同步状态</span><span class="value">${App.syncStatusText}</span></div>
        <div class="settings-item"><span class="label">待同步变更</span><span class="value">${offlineQueue.length} 条</span></div>
        <button class="btn btn-secondary btn-block" style="margin-top:8px" onclick="App.manualSync()">手动同步</button></div>
      <div class="settings-section"><h4>数据管理</h4>
        <button class="btn btn-secondary btn-block" style="margin-bottom:8px" onclick="App.exportData()">导出全部数据 (JSON)</button>
        <button class="btn btn-secondary btn-block" style="margin-bottom:8px" onclick="UI.showImportModal()">从 JSON 导入数据</button>
        <button class="btn btn-danger btn-block" onclick="App.clearAllData()">清除本地数据并登出</button></div>
      <div class="settings-section"><h4>关于</h4>
        <div class="settings-item"><span class="label">版本</span><span class="value">1.0.0</span></div>
        <div class="settings-item"><span class="label">仓库</span><span class="value">${config.repo || '未配置'}</span></div>
        <div style="font-size:12px;color:var(--text-light);margin-top:8px;line-height:1.6">共享衣柜 App — 基于 GitHub 的多设备同步衣柜管理。<br>数据存储在你的 GitHub 仓库中，两台设备配置同一仓库即可同步。</div></div>`;
  },

  toggleToken() { const input = this.$('settingToken'); input.type = input.type === 'password' ? 'text' : 'password'; },

  openWardrobeDrawer() { this.renderWardrobeList(); this.$('wardrobeDrawerOverlay').classList.add('show'); },
  closeWardrobeDrawer() { this.$('wardrobeDrawerOverlay').classList.remove('show'); },

  renderWardrobeList() {
    const state = App.state;
    const wardrobes = state.wardrobes || [];
    const currentUser = state.config.username;
    const visible = wardrobes.filter(w => w.owner === currentUser || w.visibility === 'shared');
    let html = '';
    if (visible.length === 0) html = '<div class="empty-state" style="padding:24px"><div class="icon">👔</div><div class="text">还没有衣柜</div></div>';
    else {
      visible.forEach(w => {
        const isOwner = w.owner === currentUser;
        const isActive = state.currentWardrobeId === w.id;
        const count = (state.allWardrobeData && state.allWardrobeData[w.id]) ? (state.allWardrobeData[w.id].clothes || []).length : 0;
        const coverUrl = GitHub.rawUrl(w.coverImage);
        const cover = coverUrl ? `<img src="${coverUrl}" class="wardrobe-cover" alt="">` : `<div class="wardrobe-cover">👔</div>`;
        html += `<div class="wardrobe-item ${isActive ? 'active' : ''}" onclick="App.switchWardrobe('${w.id}')">${cover}
          <div class="wardrobe-meta"><div class="name">${w.name}</div><div class="sub">${w.owner} · ${count} 件衣物</div></div>
          ${!isOwner ? '<span class="wardrobe-badge">共享</span>' : ''}
          ${isOwner ? `<span class="wardrobe-edit" onclick="event.stopPropagation();App.editWardrobe('${w.id}')">✏️</span>` : ''}
        </div>`;
      });
    }
    this.$('wardrobeList').innerHTML = html;
  },

  renderSelectBar() {
    const state = App.state;
    const count = (state.selectedClotheIds || []).length;
    const mode = state.recommendMode ? '推荐' : '穿搭';
    let bar = document.getElementById('selectBar');
    if (!bar) { bar = document.createElement('div'); bar.id = 'selectBar'; bar.className = 'select-bar'; document.body.appendChild(bar); }
    bar.innerHTML = `<span class="count">已选 ${count} 件</span><div style="display:flex;gap:8px"><button class="btn btn-secondary btn-sm" onclick="App.cancelSelect()">取消</button><button class="btn btn-primary btn-sm" onclick="App.confirmSelect()" ${count === 0 ? 'disabled' : ''}>确认${mode}</button></div>`;
    bar.style.display = 'flex';
  },
  hideSelectBar() { const bar = document.getElementById('selectBar'); if (bar) bar.style.display = 'none'; },

  showImportModal() {
    this.showModal('导入数据', `<div class="form-group"><label>选择 JSON 文件</label><input type="file" id="importFile" accept=".json"></div><div style="font-size:12px;color:var(--text-light);margin-bottom:16px">导入将覆盖当前所有本地数据，建议先导出备份。</div><button class="btn btn-primary btn-block" onclick="App.doImport()">确认导入</button>`);
  },

  formatTime(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    return `${d.getMonth() + 1}月${d.getDate()}日 ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }
};
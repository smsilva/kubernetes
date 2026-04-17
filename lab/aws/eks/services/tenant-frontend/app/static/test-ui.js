/* test-ui.js — shared test page logic for design sandbox and tenant-frontend service */

(function () {
  'use strict';

  // ── Shared state ────────────────────────────────────────────────────────────
  const testResults = {};
  let _testCases  = [];
  let _jwtToken   = null;

  // ── SVG paths ───────────────────────────────────────────────────────────────
  const CHECK_PATH     = 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z';
  const CROSS_PATH     = 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z';
  const CLIPBOARD_PATH = 'M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z';

  // ── Utilities ────────────────────────────────────────────────────────────────
  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function _fallbackCopy(text, onSuccess) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try { document.execCommand('copy'); onSuccess(); } catch (e) {}
    document.body.removeChild(ta);
  }

  // ── Accordion ────────────────────────────────────────────────────────────────
  function toggleAccordion(label) {
    const body    = document.getElementById('body-' + label);
    const chevron = document.getElementById('chevron-' + label);
    const header  = body.previousElementSibling;
    const isOpen  = body.style.display !== 'none';
    body.style.display      = isOpen ? 'none' : 'block';
    chevron.style.transform = isOpen ? '' : 'rotate(180deg)';
    header.setAttribute('aria-expanded', String(!isOpen));
  }

  function openAccordion(label) {
    const body = document.getElementById('body-' + label);
    if (body && body.style.display === 'none') toggleAccordion(label);
  }

  function collapseAll() {
    _testCases.forEach(function (t) {
      const body = document.getElementById('body-' + t.label);
      if (body && body.style.display !== 'none') toggleAccordion(t.label);
    });
  }

  // ── Copy curl ────────────────────────────────────────────────────────────────
  function copyCurl(btn) {
    const label = btn.dataset ? btn.dataset.label : btn.getAttribute('data-label');
    const t = _testCases.find(function (r) { return r.label === label; });
    if (!t || !t.curl_cmd) return;
    const done = function () {
      const path = btn.querySelector('path');
      path.setAttribute('d', CHECK_PATH);
      btn.classList.add('copy-btn-ok');
      setTimeout(function () {
        path.setAttribute('d', CLIPBOARD_PATH);
        btn.classList.remove('copy-btn-ok');
      }, 1500);
    };
    if (navigator.clipboard) {
      navigator.clipboard.writeText(t.curl_cmd).then(done).catch(function () { _fallbackCopy(t.curl_cmd, done); });
    } else {
      _fallbackCopy(t.curl_cmd, done);
    }
  }

  // ── Summary + progress ───────────────────────────────────────────────────────
  function updateSummary() {
    let passed = 0, failed = 0, running = 0;
    _testCases.forEach(function (t) {
      const circle = document.getElementById('circle-' + t.label);
      if (!circle) return;
      if      (circle.classList.contains('item-circle-pass'))    passed++;
      else if (circle.classList.contains('item-circle-fail'))    failed++;
      else if (circle.classList.contains('item-circle-running')) running++;
    });
    document.getElementById('count-passed').textContent = passed;
    document.getElementById('count-failed').textContent = failed;
    const runningEl  = document.getElementById('summary-running');
    const runningSep = document.getElementById('summary-running-sep');
    if (running > 0 && running < _testCases.length) {
      document.getElementById('count-running').textContent = running;
      runningEl.style.display  = '';
      runningSep.style.display = '';
    } else {
      runningEl.style.display  = 'none';
      runningSep.style.display = 'none';
    }
    const done = passed + failed;
    if (done > 0) {
      const pct = Math.round((passed / _testCases.length) * 100);
      document.getElementById('test-progress-wrap').classList.add('visible');
      document.getElementById('test-progress-fill').style.width = pct + '%';
      document.getElementById('test-progress-pct').textContent  = pct + '%';
      document.getElementById('test-progress-lbl').textContent  = passed + ' / ' + _testCases.length + ' passed';
    }
  }

  // ── Running state ────────────────────────────────────────────────────────────
  function setRunning(label) {
    document.getElementById('result-' + label).innerHTML = '<span class="test-running">Running\u2026</span>';
    const circle = document.getElementById('circle-' + label);
    if (circle) { circle.className = 'item-circle item-circle-running'; circle.innerHTML = ''; }
    const badge = document.getElementById('badge-' + label);
    if (badge) { badge.className = 'badge badge-running'; badge.textContent = '\u2026'; badge.style.visibility = 'visible'; }
    const item = document.getElementById('item-' + label);
    if (item) { item.classList.remove('accordion-item--pass', 'accordion-item--fail'); }
    updateSummary();
  }

  // ── Render result ────────────────────────────────────────────────────────────
  function renderResult(label, t) {
    testResults[label] = t;

    const passed = t.status_code === t.expected;
    const circle = document.getElementById('circle-' + label);
    if (circle) {
      circle.className = passed ? 'item-circle item-circle-pass' : 'item-circle item-circle-fail';
      circle.innerHTML = passed
        ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CHECK_PATH + '" fill="currentColor"/></svg>'
        : '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CROSS_PATH + '" fill="currentColor"/></svg>';
    }

    const badge = document.getElementById('badge-' + label);
    if (badge) {
      badge.textContent = t.status_code != null ? t.status_code : t.expected;
      badge.className   = 'badge ' + (passed ? 'badge-ok' : 'badge-deny');
      badge.style.visibility = 'visible';
    }

    const statusLabel = passed
      ? '<span class="result-pass"><svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CHECK_PATH + '" fill="currentColor"/></svg>HTTP ' + t.status_code + ' \u2014 passed</span>'
      : '<span class="result-fail"><svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CROSS_PATH + '" fill="currentColor"/></svg>' + (t.status_code ? 'HTTP ' + t.status_code : escapeHtml(t.error)) + ' \u2014 failed</span>';

    const hasDetail = !!t.result_json;
    let html = '<div class="result-detail-toggle" onclick="window._testUi.toggleResultDetail(\'' + label + '\')" style="' + (hasDetail ? '' : 'cursor:default') + '">'
      + statusLabel
      + (hasDetail ? '<svg class="result-detail-chevron" id="detail-chevron-' + label + '" width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M7 10l5 5 5-5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>' : '')
      + '</div>';

    if (hasDetail) {
      html += '<div class="result-detail-panel" id="detail-' + label + '">'
        + '<div class="result-code-wrap">'
        + '<div class="result-code-actions">'
        + '<button class="drawer-wrap-btn active" id="wrap-result-' + label + '" onclick="event.stopPropagation();window._testUi.toggleResultWrap(\'' + label + '\')" title="Toggle wrap">wrap</button>'
        + '<button class="result-copy-btn" id="copy-result-' + label + '" onclick="event.stopPropagation();window._testUi.copyResult(\'' + label + '\')" title="Copy">'
        + '<svg width="13" height="13" viewBox="0 0 24 24" fill="none"><path d="' + CLIPBOARD_PATH + '" fill="currentColor"/></svg>'
        + '</button>'
        + '<button class="result-fullscreen-btn" onclick="event.stopPropagation();window._testUi.openDrawer(\'' + label + '\')" title="Fullscreen">'
        + '<svg width="13" height="13" viewBox="0 0 24 24" fill="none"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        + '</button>'
        + '</div>'
        + '<pre class="result-code-pre" id="result-pre-' + label + '">' + escapeHtml(t.result_json) + '</pre>'
        + '</div>'
        + '</div>';
    }

    document.getElementById('result-' + label).innerHTML = html;
    const item = document.getElementById('item-' + label);
    if (item) {
      item.classList.toggle('accordion-item--pass', passed);
      item.classList.toggle('accordion-item--fail', !passed);
    }
    updateSummary();
  }

  function toggleResultDetail(label) {
    const panel   = document.getElementById('detail-' + label);
    const chevron = document.getElementById('detail-chevron-' + label);
    if (!panel) return;
    const open = panel.classList.toggle('open');
    if (chevron) chevron.classList.toggle('open', open);
  }

  function toggleResultWrap(label) {
    const pre = document.getElementById('result-pre-' + label);
    const btn = document.getElementById('wrap-result-' + label);
    if (!pre || !btn) return;
    const nowWrapped = pre.classList.toggle('nowrap');
    btn.classList.toggle('active', !nowWrapped);
  }

  function copyResult(label) {
    const pre = document.getElementById('result-pre-' + label);
    const btn = document.getElementById('copy-result-' + label);
    if (!pre || !btn) return;
    const done = function () {
      btn.classList.add('ok');
      setTimeout(function () { btn.classList.remove('ok'); }, 1500);
    };
    if (navigator.clipboard) {
      navigator.clipboard.writeText(pre.textContent).then(done).catch(function () { _fallbackCopy(pre.textContent, done); });
    } else {
      _fallbackCopy(pre.textContent, done);
    }
  }

  // ── Result drawer (fullscreen modal) ─────────────────────────────────────────
  function openDrawer(label) {
    const t      = _testCases.find(function (r) { return r.label === label; });
    const result = testResults[label];

    document.getElementById('result-drawer-title').textContent = t ? t.name : label;

    let body = '';
    if (result) {
      const passed = result.status_code === result.expected;
      const statusHtml = passed
        ? '<span class="result-pass"><svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CHECK_PATH + '" fill="currentColor"/></svg>HTTP ' + result.status_code + ' \u2014 passed</span>'
        : '<span class="result-fail"><svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="' + CROSS_PATH + '" fill="currentColor"/></svg>' + (result.status_code ? 'HTTP ' + result.status_code : escapeHtml(result.error)) + ' \u2014 failed</span>';
      body += '<div style="padding:2px 0 4px;font-size:13px">' + statusHtml + '</div>';

      if (result.result_json) {
        body += '<div class="drawer-code-block">'
          + '<div class="drawer-code-header"><span>response body</span>'
          + '<div class="drawer-code-header-actions">'
          + '<button class="drawer-wrap-btn active" id="wrap-json-' + label + '" onclick="window._testUi.toggleDrawerWrap(\'dpre-json-' + label + '\',\'wrap-json-' + label + '\')">wrap</button>'
          + '<button class="copy-btn" style="position:static;width:28px;height:24px" onclick="navigator.clipboard&&navigator.clipboard.writeText(document.getElementById(\'dpre-json-' + label + '\').textContent)" title="Copy">'
          + '<svg width="12" height="12" viewBox="0 0 24 24" fill="none"><path d="' + CLIPBOARD_PATH + '" fill="currentColor"/></svg>'
          + '</button>'
          + '</div></div>'
          + '<pre class="drawer-code-pre wrap" id="dpre-json-' + label + '">' + escapeHtml(result.result_json) + '</pre>'
          + '</div>';
      }
    } else {
      body += '<p style="color:var(--color-secondary);font-size:13px">Run this test first to see results.</p>';
    }

    if (t) {
      body += '<div class="drawer-code-block">'
        + '<div class="drawer-code-header"><span>curl command</span>'
        + '<div class="drawer-code-header-actions">'
        + '<button class="drawer-wrap-btn active" id="wrap-curl-' + label + '" onclick="window._testUi.toggleDrawerWrap(\'dpre-curl-' + label + '\',\'wrap-curl-' + label + '\')">wrap</button>'
        + '<button class="copy-btn" style="position:static;width:28px;height:24px" onclick="navigator.clipboard&&navigator.clipboard.writeText(document.getElementById(\'dpre-curl-' + label + '\').textContent)" title="Copy">'
        + '<svg width="12" height="12" viewBox="0 0 24 24" fill="none"><path d="' + CLIPBOARD_PATH + '" fill="currentColor"/></svg>'
        + '</button>'
        + '</div></div>'
        + '<pre class="drawer-code-pre wrap" id="dpre-curl-' + label + '">' + escapeHtml(t.curl_cmd) + '</pre>'
        + '</div>';
    }

    document.getElementById('result-drawer-body').innerHTML = body;
    document.getElementById('result-drawer').classList.add('open');
    document.getElementById('result-drawer-overlay').classList.add('open');
  }

  function closeDrawer() {
    document.getElementById('result-drawer').classList.remove('open');
    document.getElementById('result-drawer-overlay').classList.remove('open');
  }

  function toggleDrawerWrap(preId, btnId) {
    const pre = document.getElementById(preId);
    const btn = document.getElementById(btnId);
    if (!pre || !btn) return;
    const wrapped = pre.classList.toggle('wrap');
    btn.classList.toggle('active', wrapped);
  }

  // ── Test runner ──────────────────────────────────────────────────────────────
  async function runSingle(label, url, expected, withJwt) {
    setRunning(label);
    openAccordion(label);
    try {
      const headers = {};
      if (withJwt && _jwtToken) headers['Authorization'] = 'Bearer ' + _jwtToken;
      const resp = await fetch(url, { headers: headers, mode: 'cors' });
      let resultJson = null;
      const ct = resp.headers.get('content-type') || '';
      if (ct.includes('application/json')) {
        try { resultJson = JSON.stringify(await resp.json(), null, 2); } catch (e) {}
      }
      renderResult(label, { status_code: resp.status, expected: expected, result_json: resultJson, error: null });
    } catch (e) {
      renderResult(label, { status_code: null, expected: expected, result_json: null, error: e.message || String(e) });
    }
  }

  async function runAll() {
    const btn = document.getElementById('run-all-btn');
    if (btn) btn.disabled = true;
    await Promise.all(_testCases.map(function (t) { return window.runSingle(t.label, t.url, t.expected, t.with_jwt); }));
    if (btn) btn.disabled = false;
  }

  // ── Public API ───────────────────────────────────────────────────────────────
  window._testUi = {
    toggleAccordion:   toggleAccordion,
    collapseAll:       collapseAll,
    copyCurl:          copyCurl,
    runSingle:         runSingle,
    runAll:            runAll,
    renderResult:      renderResult,
    toggleResultDetail:toggleResultDetail,
    toggleResultWrap:  toggleResultWrap,
    copyResult:        copyResult,
    openDrawer:        openDrawer,
    closeDrawer:       closeDrawer,
    toggleDrawerWrap:  toggleDrawerWrap,
  };

  // ── Init ─────────────────────────────────────────────────────────────────────
  window.initTestPage = function (opts) {
    _testCases = opts.testCases || [];
    _jwtToken  = opts.jwtToken  || null;

    // Expose helpers globally so inline onclick= attrs work
    window.toggleAccordion    = toggleAccordion;
    window.collapseAll        = collapseAll;
    window.copyCurl           = copyCurl;
    window.runSingle          = runSingle;
    window.runAll             = runAll;
    window.setRunning         = setRunning;
    window.renderResult       = renderResult;
    window.openDrawer         = openDrawer;
    window.closeDrawer        = closeDrawer;
    window.toggleDrawerWrap   = toggleDrawerWrap;
    window.toggleResultDetail = toggleResultDetail;
    window.toggleResultWrap   = toggleResultWrap;
    window.copyResult         = copyResult;
    window.escapeHtml         = escapeHtml;

    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeDrawer(); });
  };
}());

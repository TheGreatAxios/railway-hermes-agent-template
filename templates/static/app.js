// Hermes Agent Railway Dashboard - Frontend JavaScript

// Global state
let currentTab = 'overview';
let autoRefreshInterval = null;
let logAutoScroll = true;

// =============================================================================
// Authentication
// =============================================================================

function getAuthHeaders() {
    const username = localStorage.getItem('hermes_username') || '';
    const password = localStorage.getItem('hermes_password') || '';
    if (username && password) {
        return {
            'Authorization': 'Basic ' + btoa(username + ':' + password)
        };
    }
    return {};
}

function handleAuthError() {
    localStorage.removeItem('hermes_username');
    localStorage.removeItem('hermes_password');
    window.location.href = '/login';
}

async function apiRequest(url, options = {}) {
    const headers = {
        ...getAuthHeaders(),
        ...options.headers
    };

    try {
        const response = await fetch(url, {
            ...options,
            headers
        });

        if (response.status === 401) {
            handleAuthError();
            return null;
        }

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

// =============================================================================
// Login
// =============================================================================

if (document.getElementById('loginForm')) {
    document.getElementById('loginForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const errorDiv = document.getElementById('error');

        try {
            // Test authentication
            const response = await fetch('/', {
                headers: {
                    'Authorization': 'Basic ' + btoa(username + ':' + password)
                }
            });

            if (response.ok) {
                localStorage.setItem('hermes_username', username);
                localStorage.setItem('hermes_password', password);
                window.location.href = '/';
            } else {
                errorDiv.textContent = 'Invalid username or password';
                errorDiv.style.display = 'block';
            }
        } catch (error) {
            errorDiv.textContent = 'Connection error. Please try again.';
            errorDiv.style.display = 'block';
        }
    });
}

function logout() {
    localStorage.removeItem('hermes_username');
    localStorage.removeItem('hermes_password');
    window.location.href = '/login';
}

// =============================================================================
// Tab Navigation
// =============================================================================

function initTabs() {
    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;
            switchTab(tabName);
        });
    });
}

function switchTab(tabName) {
    currentTab = tabName;

    // Update nav
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.tab === tabName);
    });

    // Update content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(`tab-${tabName}`).classList.add('active');

    // Load tab data
    if (tabName === 'overview') {
        loadOverview();
    } else if (tabName === 'config') {
        loadConfig();
    } else if (tabName === 'logs') {
        loadLogs();
    } else if (tabName === 'status') {
        loadStatus();
    }
}

// =============================================================================
// Overview Tab
// =============================================================================

async function loadOverview() {
    try {
        const data = await apiRequest('/api/status');
        if (!data) return;

        updateGatewayStatus(data.gateway);
        updatePlatformStatus(data.platforms);
        updateProviderStatus(data.providers);
    } catch (error) {
        console.error('Failed to load overview:', error);
    }
}

function updateGatewayStatus(gateway) {
    const statusBadge = document.getElementById('gatewayStatus');
    const infoBox = document.getElementById('gatewayInfo');

    if (gateway.running) {
        statusBadge.textContent = 'Running';
        statusBadge.className = 'status-badge running';
        infoBox.innerHTML = `
            <p><strong>Status:</strong> Running</p>
            <p><strong>PID:</strong> ${gateway.pid}</p>
        `;
    } else if (gateway.exit_code !== undefined) {
        statusBadge.textContent = 'Stopped';
        statusBadge.className = 'status-badge stopped';
        infoBox.innerHTML = `
            <p><strong>Status:</strong> Stopped (Exit code: ${gateway.exit_code})</p>
        `;
    } else {
        statusBadge.textContent = 'Stopped';
        statusBadge.className = 'status-badge stopped';
        infoBox.innerHTML = `
            <p><strong>Status:</strong> Not running</p>
            <p>Click "Start Gateway" to begin.</p>
        `;
    }
}

function updatePlatformStatus(platforms) {
    const indicators = {
        telegram: document.getElementById('telegramStatus'),
        discord: document.getElementById('discordStatus'),
        slack: document.getElementById('slackStatus'),
        whatsapp: document.getElementById('whatsappStatus')
    };

    for (const [platform, enabled] of Object.entries(platforms)) {
        const indicator = indicators[platform];
        if (indicator) {
            indicator.textContent = enabled ? 'Enabled' : 'Disabled';
            indicator.className = `platform-indicator ${enabled ? 'enabled' : 'disabled'}`;
        }
    }
}

function updateProviderStatus(providers) {
    const container = document.getElementById('providerStatus');
    const providerNames = {
        openrouter: 'OpenRouter',
        anthropic: 'Anthropic',
        openai: 'OpenAI',
        glm: 'GLM (z.ai)',
        kimi: 'Kimi',
        minimax: 'MiniMax',
        nous: 'Nous Portal'
    };

    const items = Object.entries(providers).map(([key, active]) => {
        const name = providerNames[key] || key;
        return `
            <div class="provider-item">
                <span class="provider-indicator ${active ? 'active' : 'inactive'}"></span>
                <span>${name}</span>
            </div>
        `;
    }).join('');

    container.innerHTML = items || '<p>No providers configured</p>';
}

// =============================================================================
// Config Tab
// =============================================================================

async function loadConfig() {
    try {
        const config = await apiRequest('/api/config');
        if (!config) return;

        const editor = document.getElementById('configEditor');
        editor.value = typeof config === 'object' 
            ? JSON.stringify(config, null, 2) 
            : String(config);
    } catch (error) {
        showConfigMessage('Failed to load configuration', 'error');
    }
}

async function saveConfig() {
    const editor = document.getElementById('configEditor');
    let config;

    try {
        config = JSON.parse(editor.value);
    } catch (e) {
        showConfigMessage('Invalid JSON format', 'error');
        return;
    }

    try {
        const result = await apiRequest('/api/config', {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });

        if (result && result.success) {
            showConfigMessage('Configuration saved successfully', 'success');
        } else {
            showConfigMessage(result?.error || 'Failed to save configuration', 'error');
        }
    } catch (error) {
        showConfigMessage('Failed to save configuration', 'error');
    }
}

function resetConfig() {
    if (confirm('Reset to default configuration? This will overwrite your current settings.')) {
        const defaultConfig = {
            terminal: {
                backend: 'docker',
                cwd: '/data/workspace',
                timeout: 180
            },
            compression: {
                enabled: true,
                threshold: 0.85
            },
            models: {
                default: 'anthropic/claude-opus-4.6'
            }
        };
        document.getElementById('configEditor').value = JSON.stringify(defaultConfig, null, 2);
    }
}

function showConfigMessage(text, type) {
    const message = document.getElementById('configMessage');
    message.textContent = text;
    message.className = `message ${type}`;
    setTimeout(() => {
        message.className = 'message';
        message.textContent = '';
    }, 5000);
}

// =============================================================================
// Logs Tab
// =============================================================================

let lastLogCount = 0;

async function loadLogs() {
    const lines = document.getElementById('logLines').value || 100;
    
    try {
        const data = await apiRequest(`/api/logs?lines=${lines}`);
        if (!data || !data.logs) return;

        const viewer = document.getElementById('logViewer');
        const logs = data.logs;

        if (logs.length !== lastLogCount || viewer.innerHTML === '') {
            viewer.innerHTML = logs.map(line => 
                `<div class="log-line">${escapeHtml(line)}</div>`
            ).join('');
            
            lastLogCount = logs.length;

            if (logAutoScroll) {
                viewer.scrollTop = viewer.scrollHeight;
            }
        }
    } catch (error) {
        console.error('Failed to load logs:', error);
    }
}

function refreshLogs() {
    lastLogCount = 0;
    loadLogs();
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// =============================================================================
// Status Tab
// =============================================================================

async function loadStatus() {
    try {
        const data = await apiRequest('/api/status');
        if (!data) return;

        const container = document.getElementById('systemStatus');
        
        let html = '<div class="status-details">';
        html += `<div class="status-row"><span class="status-label">Gateway:</span><span class="status-value">${data.gateway.running ? 'Running (PID: ' + data.gateway.pid + ')' : 'Stopped'}</span></div>`;
        html += `<div class="status-row"><span class="status-label">Timestamp:</span><span class="status-value">${data.timestamp}</span></div>`;
        html += '</div>';

        container.innerHTML = html;
    } catch (error) {
        console.error('Failed to load status:', error);
    }
}

// =============================================================================
// Gateway Control
// =============================================================================

async function startGateway() {
    try {
        const result = await apiRequest('/api/gateway/start', { method: 'POST' });
        if (result) {
            updateGatewayStatus(result.status);
            alert(result.success ? 'Gateway started' : 'Failed to start gateway');
        }
    } catch (error) {
        alert('Error starting gateway: ' + error.message);
    }
}

async function stopGateway() {
    if (!confirm('Stop the gateway?')) return;
    
    try {
        const result = await apiRequest('/api/gateway/stop', { method: 'POST' });
        if (result) {
            updateGatewayStatus(result.status);
            alert(result.success ? 'Gateway stopped' : 'Failed to stop gateway');
        }
    } catch (error) {
        alert('Error stopping gateway: ' + error.message);
    }
}

async function restartGateway() {
    if (!confirm('Restart the gateway?')) return;
    
    try {
        const result = await apiRequest('/api/gateway/restart', { method: 'POST' });
        if (result) {
            updateGatewayStatus(result.status);
            alert(result.success ? 'Gateway restarted' : 'Failed to restart gateway');
        }
    } catch (error) {
        alert('Error restarting gateway: ' + error.message);
    }
}

function refreshStatus() {
    loadOverview();
}

// =============================================================================
// Auto-refresh
// =============================================================================

function startAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
    }

    autoRefreshInterval = setInterval(() => {
        if (currentTab === 'overview') {
            loadOverview();
        } else if (currentTab === 'logs') {
            loadLogs();
        } else if (currentTab === 'status') {
            loadStatus();
        }
    }, 3000); // Refresh every 3 seconds
}

// =============================================================================
// Event Listeners
// =============================================================================

if (document.getElementById('autoScroll')) {
    document.getElementById('autoScroll').addEventListener('change', (e) => {
        logAutoScroll = e.target.checked;
    });
}

// =============================================================================
// Initialize
// =============================================================================

document.addEventListener('DOMContentLoaded', () => {
    initTabs();
    
    // Load initial data
    if (document.querySelector('.app-container')) {
        loadOverview();
        startAutoRefresh();
    }
});

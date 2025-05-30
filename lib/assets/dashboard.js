console.log('🚀 Network Logger Dashboard Starting...');

let logs = [];
let allTransactions = [];
let filteredTransactions = [];
let expandedRows = new Set();
let expandedContent = new Set(); // Track expanded content sections
let userInteracting = false;
let interactionTimeout;
let lastDataHash = '';
let consecutiveNoChanges = 0;
let forceNextUpdate = false;
let rapidRefreshInterval;
let normalRefreshInterval;

// Track user interaction to pause auto-refresh (improved detection)
function setUserInteracting() {
    userInteracting = true;
    clearTimeout(interactionTimeout);
    console.log('👆 User interaction detected, pausing auto-refresh');
    
    // Longer pause for interactions like expanding rows (5 seconds instead of 1)
    interactionTimeout = setTimeout(() => {
        userInteracting = false;
        console.log('🔄 User interaction ended, resuming auto-refresh');
        // Immediately refresh after user stops interacting
        forceNextUpdate = true;
        loadLogs();
    }, 5000); // Increased from 1 second to 5 seconds
}

// Specific function for row expansion to prevent auto-close
function setUserExpandingRows() {
    userInteracting = true;
    clearTimeout(interactionTimeout);
    console.log('📋 User expanding/collapsing rows, pausing auto-refresh');
    
    // Even longer pause when user is expanding rows (15 seconds for content expansion)
    interactionTimeout = setTimeout(() => {
        userInteracting = false;
        console.log('🔄 Row interaction ended, resuming auto-refresh');
        forceNextUpdate = true;
        loadLogs();
    }, 15000); // Increased to 15 seconds for content interactions
}

// Load logs immediately when page loads
async function loadLogs() {
    // Skip refresh if user is actively interacting (more strict)
    if (userInteracting && !forceNextUpdate) {
        console.log('⏸️ Skipping refresh - user is actively interacting');
        return;
    }

    console.log('📡 Loading logs from API...');
    try {
        // Add cache busting to prevent browser caching
        const cacheBuster = `?t=${Date.now()}&r=${Math.random()}`;
        const response = await fetch(`/logs${cacheBuster}`);
        console.log('📡 Response status:', response.status);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        
        // Create a hash of the data to detect changes
        const currentDataHash = JSON.stringify(data.logs);
        
        // Force update if requested or if data actually changed
        if (forceNextUpdate || currentDataHash !== lastDataHash) {
            if (forceNextUpdate) {
                console.log('🔄 Forced update triggered');
                forceNextUpdate = false;
            } else {
                console.log('📊 Data changed, updating display');
            }
            
            consecutiveNoChanges = 0;
            lastDataHash = currentDataHash;
            logs = data.logs || [];
            console.log('📝 Total logs:', logs.length);
            
            processLogs();
            updateDisplay();
            return;
        }
        
        consecutiveNoChanges++;
        console.log('📊 No data changes detected, consecutive:', consecutiveNoChanges);
        
        // If no changes for a while, force update to ensure UI is current (but less aggressive)
        if (consecutiveNoChanges >= 15) { // Increased from 10 to 15
            console.log('🔄 Forcing update after no changes');
            lastDataHash = '';
            consecutiveNoChanges = 0;
            forceNextUpdate = true;
            logs = data.logs || [];
            processLogs();
            updateDisplay();
        }
        
    } catch (error) {
        console.error('❌ Error loading logs:', error);
        showError('Failed to load logs: ' + error.message);
        consecutiveNoChanges++;
    }
}

function processLogs() {
    console.log('🔄 Processing logs...');
    console.log('📊 Raw logs received:', logs.length);
    console.log('📋 Currently expanded rows:', Array.from(expandedRows));
    console.log('📋 Currently expanded content:', Array.from(expandedContent));
    
    // Step 1: Create a transaction for every request
    const requestTransactions = new Map();
    const responseOrErrorLogs = [];
    
    // Debug: Log all unique IDs
    const allIds = logs.map(log => log.id);
    const uniqueIds = [...new Set(allIds)];
    console.log('🆔 Unique log IDs:', uniqueIds.length, 'out of', allIds.length, 'total logs');
    
    logs.forEach(log => {
        if (log.type === 'request') {
            // Every request gets its own unique transaction using the log ID
            const transactionId = `req_${log.id}`;
            
            if (requestTransactions.has(transactionId)) {
                console.warn('⚠️ Duplicate request transaction ID:', transactionId);
            }
            
            requestTransactions.set(transactionId, {
                id: transactionId,
                url: log.url,
                method: log.method || 'UNKNOWN',
                request: log,
                response: null,
                error: null,
                timestamp: log.timestamp,
                requestTimestamp: log.timestamp,
                logId: log.id
            });
            
            console.log('➕ Created transaction for request:', transactionId, log.method, log.url);
        } else {
            // Collect responses and errors for pairing
            responseOrErrorLogs.push(log);
        }
    });
    
    console.log('📤 Request transactions created:', requestTransactions.size);
    console.log('📥 Response/Error logs to pair:', responseOrErrorLogs.length);
    
    // Step 2: Pair responses and errors with their matching requests
    responseOrErrorLogs.forEach(log => {
        // Find the best matching request transaction
        let bestMatch = null;
        let smallestTimeDiff = Infinity;
        
        for (const [transactionId, transaction] of requestTransactions) {
            // Must match method and URL
            if (transaction.method === log.method && transaction.url === log.url) {
                // Calculate time difference
                const timeDiff = Math.abs(new Date(log.timestamp) - new Date(transaction.requestTimestamp));
                
                // Only consider if this transaction doesn't already have this type of log
                const canMatch = (log.type === 'response' && !transaction.response) || 
                               (log.type === 'error' && !transaction.error);
                
                if (canMatch && timeDiff < smallestTimeDiff && timeDiff < 30000) { // within 30 seconds
                    bestMatch = transaction;
                    smallestTimeDiff = timeDiff;
                }
            }
        }
        
        if (bestMatch) {
            // Pair with the best matching request
            if (log.type === 'response') {
                bestMatch.response = log;
                console.log('🔗 Paired response to:', bestMatch.id);
            } else if (log.type === 'error') {
                bestMatch.error = log;
                console.log('🔗 Paired error to:', bestMatch.id);
            }
            
            // Update transaction timestamp to latest
            if (new Date(log.timestamp) > new Date(bestMatch.timestamp)) {
                bestMatch.timestamp = log.timestamp;
            }
        } else {
            // No matching request found, create standalone transaction
            const standaloneId = `standalone_${log.type}_${log.id}`;
            requestTransactions.set(standaloneId, {
                id: standaloneId,
                url: log.url,
                method: log.method || 'UNKNOWN',
                request: null,
                response: log.type === 'response' ? log : null,
                error: log.type === 'error' ? log : null,
                timestamp: log.timestamp,
                requestTimestamp: null,
                logId: log.id
            });
            
            console.log('📋 Created standalone transaction:', standaloneId);
        }
    });
    
    allTransactions = Array.from(requestTransactions.values())
        .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Apply current filters
    applyFilters();
    
    console.log('✅ Final result:', allTransactions.length, 'transactions from', logs.length, 'logs');
    console.log('📋 Expanded rows preserved:', Array.from(expandedRows));
    console.log('📋 Expanded content preserved:', Array.from(expandedContent));
}

function applyFilters() {
    const searchTerm = document.getElementById('searchInput') && document.getElementById('searchInput').value.toLowerCase() || '';
    const methodFilter = document.getElementById('methodFilter') && document.getElementById('methodFilter').value || '';
    const statusFilter = document.getElementById('statusFilter') && document.getElementById('statusFilter').value || '';
    
    filteredTransactions = allTransactions.filter(transaction => {
        const matchesSearch = !searchTerm || 
            transaction.url.toLowerCase().includes(searchTerm) ||
            transaction.method.toLowerCase().includes(searchTerm);
        
        const matchesMethod = !methodFilter || transaction.method === methodFilter;
        
        const statusCode = getStatusCode(transaction);
        const matchesStatus = !statusFilter || 
            (statusFilter === '2xx' && statusCode >= 200 && statusCode < 300) ||
            (statusFilter === '4xx' && statusCode >= 400 && statusCode < 500) ||
            (statusFilter === '5xx' && statusCode >= 500);
        
        return matchesSearch && matchesMethod && matchesStatus;
    });
}

function updateDisplay() {
    console.log('🎨 Updating display...');
    console.log('📊 Data summary:', {
        totalLogs: logs.length,
        allTransactions: allTransactions.length,
        filteredTransactions: filteredTransactions.length,
        expandedRows: expandedRows.size,
        expandedContent: expandedContent.size,
        userInteracting: userInteracting
    });
    updateStats();
    updateTable();
}

function updateStats() {
    const totalLogs = document.getElementById('logCount');
    const requestCount = document.getElementById('requestCount');
    const errorCount = document.getElementById('errorCount');
    const lastUpdated = document.getElementById('lastUpdated');
    
    const requests = allTransactions.filter(t => t.request).length;
    const errors = allTransactions.filter(t => t.error || (t.response && t.response.statusCode >= 400)).length;
    
    if (totalLogs) {
        totalLogs.textContent = allTransactions.length;
        // Add visual feedback for new data
        totalLogs.style.color = '#667eea';
        setTimeout(() => {
            totalLogs.style.color = '';
        }, 300);
    }
    if (requestCount) {
        requestCount.textContent = requests;
        requestCount.style.color = '#667eea';
        setTimeout(() => {
            requestCount.style.color = '';
        }, 300);
    }
    if (errorCount) {
        errorCount.textContent = errors;
        errorCount.style.color = errors > 0 ? '#e53e3e' : '#667eea';
        setTimeout(() => {
            errorCount.style.color = '';
        }, 300);
    }
    if (lastUpdated) {
        lastUpdated.textContent = new Date().toLocaleTimeString();
        lastUpdated.style.color = '#38a169';
        setTimeout(() => {
            lastUpdated.style.color = '';
        }, 500);
    }
    
    console.log('📊 Stats updated - Total:', allTransactions.length, 'Requests:', requests, 'Errors:', errors);
}

function updateTable() {
    const tableBody = document.getElementById('logsTableBody');
    if (!tableBody) return;
    
    console.log('🎨 Updating table with expanded rows:', Array.from(expandedRows));
    console.log('🎨 And expanded content:', Array.from(expandedContent));
    
    if (filteredTransactions.length === 0) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="6" class="empty-state">
                    <h3>📡 No network activity</h3>
                    <p>Make HTTP requests in your Flutter app to see them here</p>
                </td>
            </tr>
        `;
        return;
    }
    
    let html = '';
    filteredTransactions.forEach(transaction => {
        const statusCode = getStatusCode(transaction);
        const statusClass = getStatusClass(statusCode);
        const time = new Date(transaction.timestamp).toLocaleTimeString();
        const isExpanded = expandedRows.has(transaction.id);
        
        console.log(`🔍 Transaction ${transaction.id}: expanded=${isExpanded}`);
        
        html += `
            <tr onclick="toggleDetails('${transaction.id}')" style="cursor: pointer;" class="${isExpanded ? 'expanded' : ''}">
                <td><span class="expand-icon">${isExpanded ? '▼' : '▶'}</span></td>
                <td><span class="type-badge ${getTypeClass(transaction)}">${getTypeText(transaction)}</span></td>
                <td><span class="method ${transaction.method}">${transaction.method}</span></td>
                <td><span class="url" title="${transaction.url}">${transaction.url}</span></td>
                <td><span class="status-code ${statusClass}">${statusCode}</span></td>
                <td><span class="timestamp">${time}</span></td>
            </tr>
        `;
        
        if (isExpanded) {
            html += `
                <tr class="details-row" style="display: table-row;">
                    <td colspan="6">
                        <div class="details-content">
                            ${createDetailedView(transaction)}
                        </div>
                    </td>
                </tr>
            `;
        }
    });
    
    tableBody.innerHTML = html;
    console.log('🎨 Table updated with', filteredTransactions.length, 'transactions and', expandedRows.size, 'expanded rows');
}

function getStatusCode(transaction) {
    if (transaction.error) return 'ERROR';
    if (transaction.response && transaction.response.statusCode) return transaction.response.statusCode;
    return 'PENDING';
}

function getStatusClass(statusCode) {
    if (statusCode === 'ERROR') return 'status-4xx';
    if (statusCode === 'PENDING') return '';
    
    const code = parseInt(statusCode);
    if (code >= 200 && code < 300) return 'status-2xx';
    if (code >= 300 && code < 400) return 'status-3xx';
    if (code >= 400 && code < 500) return 'status-4xx';
    if (code >= 500) return 'status-5xx';
    return '';
}

function getTypeClass(transaction) {
    if (transaction.error) return 'type-error';
    if (transaction.response) return 'type-response';
    return 'type-request';
}

function getTypeText(transaction) {
    if (transaction.error) return 'ERROR';
    if (transaction.response) return 'COMPLETE';
    return 'PENDING';
}

function formatJSON(data) {
    try {
        // If it's already a string, try to parse it first
        if (typeof data === 'string') {
            try {
                data = JSON.parse(data);
            } catch (e) {
                // If parsing fails, return the original string
                return data;
            }
        }
        
        // Pretty print the JSON with 2-space indentation
        return JSON.stringify(data, null, 2);
    } catch (error) {
        // If JSON formatting fails, return the original data
        return typeof data === 'string' ? data : String(data);
    }
}

// Create stable content IDs based on transaction and content type
function createContentId(transactionId, contentType) {
    return `${transactionId}_${contentType}`;
}

function createExpandableContent(title, content, maxHeight = '200px', transactionId, contentType) {
    const contentId = createContentId(transactionId, contentType);
    const isLongContent = content.length > 500;
    const isExpanded = expandedContent.has(contentId);
    
    if (!isLongContent) {
        return `<div class="content-section">
            <h5>${title}</h5>
            <pre class="json-content">${content}</pre>
        </div>`;
    }
    
    // Determine styles and button text based on expanded state
    const styles = isExpanded ? 
        'max-height: none; overflow: visible;' : 
        `max-height: ${maxHeight}; overflow: hidden;`;
    const buttonText = isExpanded ? '[Collapse]' : '[Expand]';
    
    return `<div class="content-section">
        <h5>${title} <button class="expand-btn" onclick="toggleContent('${contentId}'); event.stopPropagation();">${buttonText}</button></h5>
        <pre class="json-content expandable-content" id="${contentId}" style="${styles}">${content}</pre>
    </div>`;
}

function toggleContent(contentId) {
    console.log('🔄 Toggling content:', contentId);
    setUserExpandingRows(); // Pause auto-refresh when expanding content
    
    if (expandedContent.has(contentId)) {
        expandedContent.delete(contentId);
        console.log('➖ Collapsed content:', contentId);
    } else {
        expandedContent.add(contentId);
        console.log('➕ Expanded content:', contentId);
    }
    
    // Apply the change immediately to the DOM element
    const element = document.getElementById(contentId);
    const button = element.previousElementSibling.querySelector('.expand-btn');
    
    if (expandedContent.has(contentId)) {
        element.style.maxHeight = 'none';
        element.style.overflow = 'visible';
        button.textContent = '[Collapse]';
    } else {
        element.style.maxHeight = '200px';
        element.style.overflow = 'hidden';
        button.textContent = '[Expand]';
    }
    
    console.log('📋 Current expanded content:', Array.from(expandedContent));
}

function toggleDetails(transactionId) {
    console.log('🔄 Toggling details for:', transactionId);
    setUserExpandingRows(); // Use specific function for row expansion
    
    if (expandedRows.has(transactionId)) {
        expandedRows.delete(transactionId);
        console.log('➖ Collapsed row:', transactionId);
    } else {
        expandedRows.add(transactionId);
        console.log('➕ Expanded row:', transactionId);
    }
    
    console.log('📋 Current expanded rows:', Array.from(expandedRows));
    updateTable();
}

function showError(message) {
    const tableBody = document.getElementById('logsTableBody');
    if (tableBody) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="6" class="empty-state" style="color: #e53e3e;">
                    <h3>⚠️ Error</h3>
                    <p>${message}</p>
                </td>
            </tr>
        `;
    }
    console.error('❌', message);
}

// Button handlers
function refreshLogs() {
    console.log('🔄 Manual refresh triggered');
    lastDataHash = ''; // Force refresh
    consecutiveNoChanges = 0;
    forceNextUpdate = true;
    userInteracting = false; // Stop any interaction pausing
    clearTimeout(interactionTimeout);
    loadLogs();
}

async function clearLogs() {
    if (!confirm('Clear all logs?')) return;
    
    userInteracting = false; // Stop any interaction pausing
    clearTimeout(interactionTimeout);
    
    try {
        const response = await fetch('/logs/clear', { method: 'POST' });
        if (response.ok) {
            logs = [];
            allTransactions = [];
            filteredTransactions = [];
            expandedRows.clear();
            expandedContent.clear(); // Clear expanded content state
            lastDataHash = '';
            consecutiveNoChanges = 0;
            forceNextUpdate = true;
            updateDisplay();
            console.log('🗑️ Logs cleared');
            // Force immediate refresh after clear
            setTimeout(() => loadLogs(), 100);
        }
    } catch (error) {
        console.error('❌ Error clearing logs:', error);
    }
}

// Filter function
function filterTransactions() {
    setUserInteracting(); // Mark as user interaction
    applyFilters();
    updateTable();
}

function createDetailedView(transaction) {
    let html = '';
    
    // Transaction Overview
    html += `
        <div class="transaction-overview">
            <h4><span class="status-indicator ${getStatusIndicatorClass(transaction)}"></span>Transaction Overview</h4>
            <div class="overview-grid">
                <div class="overview-item">
                    <strong>URL:</strong> <span class="url-text">${transaction.url}</span>
                </div>
                <div class="overview-item">
                    <strong>Method:</strong> <span class="method-badge ${transaction.method}">${transaction.method}</span>
                </div>
                <div class="overview-item">
                    <strong>Status:</strong> <span class="status-code ${getStatusClass(getStatusCode(transaction))}">${getStatusCode(transaction)}</span>
                </div>
                <div class="overview-item">
                    <strong>Time:</strong> <span class="timestamp">${new Date(transaction.timestamp).toLocaleString()}</span>
                </div>
            </div>
        </div>
    `;
    
    // Request Details
    if (transaction.request) {
        const req = transaction.request;
        html += `<div class="request-section">
            <h4>📤 Request Details</h4>`;
            
        if (req.headers) {
            html += createExpandableContent('Request Headers', formatJSON(req.headers), '150px', transaction.id, 'request_headers');
        }
        
        if (req.requestBody) {
            html += createExpandableContent('Request Body', formatJSON(req.requestBody), '200px', transaction.id, 'request_body');
        }
        
        html += `</div>`;
    }
    
    // Response Details
    if (transaction.response) {
        const res = transaction.response;
        html += `<div class="response-section">
            <h4>📥 Response Details</h4>`;
            
        if (res.headers) {
            html += createExpandableContent('Response Headers', formatJSON(res.headers), '150px', transaction.id, 'response_headers');
        }
        
        if (res.responseBody) {
            html += createExpandableContent('Response Body', formatJSON(res.responseBody), '300px', transaction.id, 'response_body');
        }
        
        html += `</div>`;
    }
    
    // Error Details
    if (transaction.error) {
        html += `<div class="error-section">
            <h4>❌ Error Details</h4>
            ${createExpandableContent('Error Information', formatJSON(transaction.error), '200px', transaction.id, 'error_info')}
        </div>`;
    }
    
    return html;
}

function getStatusIndicatorClass(transaction) {
    if (transaction.error) return 'status-error';
    if (transaction.response) {
        const statusCode = parseInt(getStatusCode(transaction));
        if (statusCode >= 200 && statusCode < 400) return 'status-success';
        return 'status-error';
    }
    return 'status-pending';
}

// Initialize everything when page loads
document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DOM loaded, initializing...');
    
    // Set up event listeners with minimal interaction detection
    const searchInput = document.getElementById('searchInput');
    const methodFilter = document.getElementById('methodFilter');
    const statusFilter = document.getElementById('statusFilter');
    
    if (searchInput) {
        searchInput.addEventListener('input', filterTransactions);
        // Only pause on actual typing in search box
        searchInput.addEventListener('input', setUserInteracting);
    }
    if (methodFilter) {
        methodFilter.addEventListener('change', filterTransactions);
    }
    if (statusFilter) {
        statusFilter.addEventListener('change', filterTransactions);
    }
    
    // Load initial data
    loadLogs();
    
    // Normal auto-refresh every 3 seconds (less aggressive)
    normalRefreshInterval = setInterval(() => {
        if (!userInteracting) {
            console.log('⏰ Normal auto-refresh interval...');
            loadLogs();
        } else {
            console.log('⏸️ Skipping normal refresh - user interacting');
        }
    }, 3000); // Increased from 2000ms to 3000ms
    
    // Rapid refresh for new data (every 1.5 seconds for first 1 minute, but respects user interaction)
    let rapidRefreshCount = 0;
    rapidRefreshInterval = setInterval(() => {
        if (rapidRefreshCount >= 40) { // Stop rapid refresh after 1 minute (40 * 1500ms)
            clearInterval(rapidRefreshInterval);
            console.log('🏁 Stopping rapid refresh mode');
            return;
        }
        
        // Only refresh during rapid mode if user is not interacting
        if (!userInteracting) {
            console.log('⚡ Rapid refresh...');
            loadLogs();
        } else {
            console.log('⏸️ Skipping rapid refresh - user interacting');
        }
        rapidRefreshCount++;
    }, 1500); // Increased from 1000ms to 1500ms
});

console.log('✅ Network Logger Dashboard JavaScript Loaded!');

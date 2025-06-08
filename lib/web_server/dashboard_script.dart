/// JavaScript functionality for the network logger dashboard.
///
/// This script provides real-time updates, filtering, searching,
/// and interactive features for the dashboard.
class DashboardScript {
  /// Returns the complete JavaScript code for the dashboard.
  static String getScript() {
    return r'''
    console.log('🚀 Network Logger Dashboard Starting...');
    
    let logs = [];
    let allTransactions = [];
    let filteredTransactions = [];
    let expandedRows = new Set();
    let userInteracting = false;
    let interactionTimeout;
    let lastDataHash = '';
    let consecutiveNoChanges = 0;
    let forceNextUpdate = false;
    let ws = null;
    let wsConnected = false;
    let wsReconnectTimeout = null;
    let isScrolling = false;
    let scrollTimeout;
    let pendingUpdates = false; // Flag to track if updates are waiting

    // --- Section expand/collapse state for inner details ---
    const sectionExpandedState = {};
    
    function getSectionKey(transactionId, section) {
        return `${transactionId}_${section}`;
    }

    function createExpandableSection(title, content, emoji, transactionId, section, defaultExpanded = false) {
        const sectionKey = getSectionKey(transactionId, section);
        const isExpanded = sectionExpandedState[sectionKey] !== undefined ? 
            sectionExpandedState[sectionKey] : defaultExpanded;
        
        // Ensure we store raw content, not formatted HTML
        let rawContent;
        let isTruncated = false;
        let truncationInfo = '';
        
        if (typeof content === 'string') {
            // If content is already a string, check if it contains HTML tags
            if (content.includes('<span class="json-')) {
                // This indicates it's already been formatted as HTML - try to extract raw content
                // This is a fallback for cases where content was double-processed
                console.warn('Content appears to be HTML formatted, attempting to extract raw data');
                rawContent = content.replace(/<[^>]*>/g, ''); // Strip HTML tags as a fallback
            } else {
                rawContent = content;
            }
        } else if (content && typeof content === 'object' && content.truncated) {
            // Handle new truncation format from interceptor
            rawContent = content.data;
            isTruncated = true;
            truncationInfo = content.truncationInfo || `Truncated from ${content.originalSize} to ${content.truncatedSize} characters`;
            console.log(`📏 Content is truncated: ${truncationInfo}`);
        } else {
            // Convert objects/arrays to JSON strings
            rawContent = JSON.stringify(content);
        }
        
        // Create a preview of the content when collapsed
        const contentPreview = rawContent.length > 150 ? 
            rawContent.substring(0, 150).replace(/\s+/g, ' ').trim() + '...' : '';
        
        const hasLongContent = rawContent.length > 500;
        const contentId = `content_${transactionId}_${section}`;
        const sizeLabel = hasLongContent ? `(${Math.ceil(rawContent.length / 1024)}KB)` : '';
        const truncationLabel = isTruncated ? ` <span style="color: #f59e0b; font-size: 10px; font-weight: 500;">TRUNCATED</span>` : '';
        
        return `
            <div class="expandable-section">
                <div class="expandable-header ${isExpanded ? 'expanded' : 'collapsed'}" 
                     onclick="toggleSection('${transactionId}', '${section}')">
                    <h5>
                        <span>${emoji}</span>
                        <span>${title}</span>
                        ${sizeLabel ? `<span style="color: #9ca3af; font-size: 10px; font-weight: 400;">${sizeLabel}</span>` : ''}
                        ${truncationLabel}
                    </h5>
                    <div class="expand-indicator">
                        ${isExpanded ? 'Collapse' : 'Expand'}
                        <span class="expand-arrow ${isExpanded ? 'expanded' : ''}">▶</span>
                    </div>
                </div>
                <div class="expandable-content ${isExpanded ? 'expanded' : ''}" id="${contentId}">
                    <div class="json-container">
                        ${isTruncated ? `<div style="background: #fef3c7; border: 1px solid #f59e0b; color: #92400e; padding: 8px; margin-bottom: 8px; border-radius: 4px; font-size: 12px;"><strong>⚠️ Content Truncated:</strong> ${escapeHtml(truncationInfo)}</div>` : ''}
                        <pre class="json-content" id="json_${contentId}" data-raw-content='${escapeForAttribute(rawContent)}' data-truncated='${isTruncated}' data-truncation-info='${escapeForAttribute(truncationInfo)}'><button class="copy-btn" onclick="copyJsonContent(event, 'json_${contentId}')">Copy</button></pre>
                    </div>
                </div>
                ${!isExpanded && contentPreview ? `
                    <div class="content-preview">
                        ${escapeHtml(contentPreview)}
                        ${isTruncated ? ' <span style="color: #f59e0b; font-size: 11px;">[TRUNCATED]</span>' : ''}
                    </div>
                ` : ''}
            </div>
        `;
    }

    function escapeForAttribute(str) {
        return str.replace(/'/g, '&#39;').replace(/"/g, '&quot;');
    }

    function toggleSection(transactionId, section) {
        console.log(`🔧 Toggling section: ${transactionId} - ${section}`);
        
        const sectionKey = getSectionKey(transactionId, section);
        const isCurrentlyExpanded = sectionExpandedState[sectionKey] || false;
        sectionExpandedState[sectionKey] = !isCurrentlyExpanded;
        
        const contentId = `content_${transactionId}_${section}`;
        const headerElement = document.querySelector(`.expandable-header[onclick*="${section}"]`);
        const contentElement = document.getElementById(contentId);
        const jsonElement = document.getElementById(`json_${contentId}`);
        const expandIndicator = headerElement?.querySelector('.expand-indicator');
        
        if (contentElement && headerElement && jsonElement) {
            if (sectionExpandedState[sectionKey]) {
                // Expanding - render the formatted content
                headerElement.classList.remove('collapsed');
                headerElement.classList.add('expanded');
                contentElement.classList.add('expanded');
                
                // Get the raw content and format it
                const rawContent = jsonElement.getAttribute('data-raw-content');
                if (rawContent) {
                    console.log(`🔍 Raw content type: ${typeof rawContent}, length: ${rawContent.length}`);
                    console.log(`🔍 Raw content preview: ${rawContent.substring(0, 200)}...`);
                    
                    const formattedContent = formatJSON(rawContent);
                    // Set the innerHTML to render the formatted HTML
                    jsonElement.innerHTML = `<button class="copy-btn" onclick="copyJsonContent(event, 'json_${contentId}')">Copy</button>${formattedContent}`;
                }
                
                if (expandIndicator) {
                    expandIndicator.innerHTML = `Collapse <span class="expand-arrow expanded">▶</span>`;
                }
                
                // Remove preview if it exists
                const preview = headerElement.parentElement.querySelector('.content-preview');
                if (preview) preview.remove();
                
                console.log(`✅ Expanded section: ${sectionKey}`);
            } else {
                // Collapsing - clear the content
                headerElement.classList.add('collapsed');
                headerElement.classList.remove('expanded');
                contentElement.classList.remove('expanded');
                
                // Clear the content when collapsed
                jsonElement.innerHTML = `<button class="copy-btn" onclick="copyJsonContent(event, 'json_${contentId}')">Copy</button>`;
                
                if (expandIndicator) {
                    expandIndicator.innerHTML = `Expand <span class="expand-arrow">▶</span>`;
                }
                
                console.log(`✅ Collapsed section: ${sectionKey}`);
            }
        }
        
        // Prevent auto-refresh while user is interacting
        userInteracting = true;
        clearTimeout(interactionTimeout);
        showInteractionNotification();
        
        interactionTimeout = setTimeout(() => {
            userInteracting = false;
            hideInteractionNotification();
            if (pendingUpdates) {
                console.log('🔄 Applying pending updates...');
                pendingUpdates = false;
                updateTable();
            }
        }, 3000);
    }

    function createExpandableContent(title, content, maxHeight = '200px', transactionId = '', section = '') {
        // Backwards compatibility - delegate to new function
        const emoji = section.includes('request') ? '📤' : 
                     section.includes('response') ? '📥' : 
                     section.includes('error') ? '❌' : '📄';
        return createExpandableSection(title, content, emoji, transactionId, section);
    }

    function showInteractionNotification() {
        let notification = document.getElementById('interactionNotification');
        if (!notification) {
            notification = document.createElement('div');
            notification.id = 'interactionNotification';
            notification.innerHTML = `
                <div style="position: fixed; bottom: 20px; right: 20px; background: rgba(76, 175, 80, 0.95); color: white; padding: 8px 12px; border-radius: 8px; box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3); z-index: 10000; font-size: 12px; max-width: 200px; backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2); animation: slideIn 0.3s ease;">
                    <div style="display: flex; align-items: center; gap: 6px;">
                        <span style="font-size: 12px;">🛡️</span>
                        <span style="font-weight: 500; font-size: 11px;">Auto-refresh paused</span>
                    </div>
                </div>
                <style>
                    @keyframes slideIn {
                        from { transform: translateX(100%); opacity: 0; }
                        to { transform: translateX(0); opacity: 1; }
                    }
                </style>
            `;
            document.body.appendChild(notification);
        }
        notification.style.display = 'block';
    }

    function hideInteractionNotification() {
        const notification = document.getElementById('interactionNotification');
        if (notification) {
            notification.style.display = 'none';
        }
    }

    function forceRefreshNow() {
        console.log('🔄 Force refresh requested by user');
        userInteracting = false;
        clearTimeout(interactionTimeout);
        hideInteractionNotification();
        pendingUpdates = false;
        updateTable();
    }

    function generateCurlCommand(request) {
        if (!request) return '';
        let curl = `curl '${request.url}' \\\n  -X ${request.method}`;
        if (request.headers) {
            Object.entries(request.headers).forEach(([k, v]) => {
                // Mask sensitive headers
                if (k.toLowerCase() === 'authorization' || k.toLowerCase() === 'cookie') {
                    curl += ` \\\n  -H '${k}: <REDACTED>'`;
                } else {
                    curl += ` \\\n  -H '${k}: ${v}'`;
                }
            });
        }
        if (request.body) {
            let body = request.body;
            if (typeof body === 'object') {
                try { body = JSON.stringify(body); } catch (e) { body = String(body); }
            }
            // Escape single quotes for shell
            body = String(body).replace(/'/g, "'\\''");
            curl += ` \\\n  --data '${body}'`;
        }
        curl += `\n# Copied from CoteNetworkLogger at ${new Date().toLocaleString()}`;
        return curl;
    }

    function copyCurlCommand(event, transactionId) {
        event.preventDefault();
        event.stopPropagation();
        const transaction = allTransactions.find(t => t.id === transactionId);
        if (!transaction || !transaction.request) return;
        const curl = generateCurlCommand(transaction.request);
        navigator.clipboard.writeText(curl).then(() => {
            const btn = event.target;
            const originalText = btn.textContent;
            btn.textContent = '✓ cURL Copied!';
            btn.style.background = 'rgba(56, 161, 105, 0.9)';
            setTimeout(() => {
                btn.textContent = originalText;
                btn.style.background = '';
            }, 2000);
        });
    }

    function createDetailedView(transaction) {
        let html = '';
        
        // Transaction Overview
        html += `
            <div class="transaction-overview">
                <h4><span class="status-indicator ${getStatusIndicatorClass(transaction)}"></span>Transaction Overview</h4>
                <div class="overview-grid">
                    <div class="overview-item">
                        <strong>URL:</strong> <span class="url-text">${transaction.url || 'N/A'}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Method:</strong> <span class="method-badge ${transaction.method || 'GET'}">${transaction.method || 'GET'}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Status:</strong> <span class="status-code ${getStatusClass(getStatusCode(transaction))}">${getStatusCode(transaction)}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Time:</strong> <span class="timestamp">${new Date(transaction.timestamp).toLocaleString()}</span>
                    </div>
                </div>
                <button class="copy-btn" style="margin-top:12px;float:right;" onclick="copyCurlCommand(event, '${transaction.id}')">Copy cURL</button>
            </div>
        `;

        // Request Details Section
        if (transaction.request) {
            const req = transaction.request;
            html += `<div class="request-section">
                <h4>📤 Request Details</h4>`;
            
            if (req.headers && Object.keys(req.headers).length > 0) {
                html += createExpandableSection(
                    'Request Headers', 
                    req.headers, // Pass raw headers object instead of formatted JSON
                    '📋',
                    transaction.id, 
                    'requestHeaders',
                    false // Default collapsed
                );
            }
            
            if (req.requestBody) {
                const isLargeBody = JSON.stringify(req.requestBody).length > 5000; // Increased threshold
                html += createExpandableSection(
                    'Request Body', 
                    req.requestBody, // Pass raw body instead of formatted JSON
                    '📝',
                    transaction.id, 
                    'requestBody',
                    true // Always expand by default for better developer experience
                );
            }
            
            html += `</div>`;
        }

        // Response Details Section
        if (transaction.response) {
            const res = transaction.response;
            html += `<div class="response-section">
                <h4>📥 Response Details</h4>`;
            
            if (res.headers && Object.keys(res.headers).length > 0) {
                html += createExpandableSection(
                    'Response Headers', 
                    res.headers, // Pass raw headers object instead of formatted JSON
                    '📋',
                    transaction.id, 
                    'responseHeaders',
                    false // Default collapsed
                );
            }
            
            if (res.responseBody !== undefined && res.responseBody !== null) {
                const isLargeBody = JSON.stringify(res.responseBody).length > 5000; // Increased threshold
                html += createExpandableSection(
                    'Response Body', 
                    res.responseBody, // Pass raw body instead of formatted JSON
                    '📄',
                    transaction.id, 
                    'responseBody',
                    true // Always expand by default for better developer experience
                );
            } else {
                // Show debug info if response body is missing
                html += `<div style="padding: 16px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; margin: 16px 0;">
                    <strong>🔍 Debug Info:</strong> Response body not found<br>
                    <small>Available fields: ${Object.keys(res).join(', ')}</small>
                </div>`;
            }
            
            // Additional response metadata if available
            if (res.statusCode || res.statusMessage || res.responseTime) {
                const metadata = {};
                if (res.statusCode) metadata.statusCode = res.statusCode;
                if (res.statusMessage) metadata.statusMessage = res.statusMessage;
                if (res.responseTime) metadata.responseTime = `${res.responseTime}ms`;
                
                html += createExpandableSection(
                    'Response Metadata', 
                    metadata, // Pass raw metadata object instead of formatted JSON
                    '⚙️',
                    transaction.id, 
                    'responseMetadata',
                    true // Default expanded for metadata
                );
            }
            
            html += `</div>`;
        }

        // Error Details Section
        if (transaction.error) {
            html += `<div class="error-section">
                <h4>❌ Error Details</h4>`;
            
            html += createExpandableSection(
                'Error Information', 
                transaction.error, // Pass raw error object instead of formatted JSON
                '🚨',
                transaction.id, 
                'errorInfo',
                true // Default expanded for errors
            );
            
            html += `</div>`;
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

    function getStatusCode(transaction) {
        if (transaction.response && transaction.response.statusCode) {
            return transaction.response.statusCode.toString();
        }
        if (transaction.error) return 'Error';
        return 'Pending';
    }

    function getStatusClass(statusCode) {
        if (statusCode === 'Error' || statusCode === 'Pending') return '';
        const code = parseInt(statusCode);
        if (code >= 200 && code < 300) return 'status-2xx';
        if (code >= 300 && code < 400) return 'status-3xx';
        if (code >= 400 && code < 500) return 'status-4xx';
        if (code >= 500) return 'status-5xx';
        return '';
    }

    function formatJSON(obj) {
        console.log(`🔧 formatJSON called with:`, typeof obj, obj);
        
        // Handle different input types more robustly
        let parsedObj;
        
        if (typeof obj === 'string') {
            console.log(`📝 Processing string content, length: ${obj.length}`);
            console.log(`📝 String preview: ${obj.substring(0, 100)}...`);
            
            // Check if the string contains HTML tags
            if (obj.includes('<span class="json-') || obj.includes('&lt;span')) {
                console.warn('⚠️ String contains HTML formatting - this should not happen!');
                // Strip HTML tags and try to extract raw content
                const stripped = obj.replace(/<[^>]*>/g, '').replace(/&lt;[^&]*&gt;/g, '');
                console.log(`🧹 Stripped content: ${stripped.substring(0, 100)}...`);
                try {
                    parsedObj = JSON.parse(stripped);
                } catch (e) {
                    console.error('❌ Failed to parse stripped content as JSON:', e);
                    return formatAsPlainText(stripped);
                }
            } else {
                try {
                    // Try to parse the string as JSON
                    parsedObj = JSON.parse(obj);
                    console.log(`✅ Successfully parsed JSON`);
                } catch (e) {
                    console.log(`📝 String is not valid JSON: ${e.message}`);
                    console.log(`📝 Trying to fix common JSON issues...`);
                    
                    // Try to clean up common issues
                    try {
                        // Remove extra escaping
                        let cleanedObj = obj.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                        
                        // If it looks like truncated JSON array/object, try to fix it
                        if ((cleanedObj.trim().startsWith('[') && !cleanedObj.trim().endsWith(']')) ||
                            (cleanedObj.trim().startsWith('{') && !cleanedObj.trim().endsWith('}'))) {
                            console.log(`🔧 Attempting to fix truncated JSON...`);
                            
                            // Try to close the structure
                            if (cleanedObj.trim().startsWith('[')) {
                                // Remove any trailing comma and close the array
                                cleanedObj = cleanedObj.replace(/,\s*$/, '') + ']';
                            } else if (cleanedObj.trim().startsWith('{')) {
                                // Remove any trailing comma and close the object
                                cleanedObj = cleanedObj.replace(/,\s*$/, '') + '}';
                            }
                        }
                        
                        parsedObj = JSON.parse(cleanedObj);
                        console.log(`✅ Successfully parsed cleaned JSON`);
                    } catch (e2) {
                        console.log(`📝 Cleanup failed, treating as plain text: ${e2.message}`);
                        // If still can't parse, return as formatted string
                        return formatAsPlainText(obj);
                    }
                }
            }
        } else if (Array.isArray(obj) || (obj && typeof obj === 'object')) {
            console.log(`📊 Processing object/array with ${Array.isArray(obj) ? obj.length + ' items' : Object.keys(obj).length + ' properties'}`);
            parsedObj = obj;
        } else {
            console.log(`🔤 Processing primitive value: ${obj}`);
            return formatAsPlainText(String(obj));
        }
        
        console.log(`✅ Successfully parsed object for formatting`);
        // Now format the parsed object with proper indentation
        return formatJSONWithSyntaxHighlighting(parsedObj);
    }

    function formatAsPlainText(text) {
        // For non-JSON text, escape HTML and preserve basic formatting
        const escaped = escapeHtml(text);
        return `<span class="json-string">${escaped}</span>`;
    }

    function formatJSONWithSyntaxHighlighting(obj) {
        // Create properly formatted JSON string with 2-space indentation
        const jsonString = JSON.stringify(obj, null, 2);
        
        if (!jsonString) {
            return '<span class="json-null">null</span>';
        }
        
        // Apply syntax highlighting line by line to preserve formatting
        const lines = jsonString.split('\n');
        const highlightedLines = lines.map(line => {
            // Escape HTML first
            let escapedLine = line
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');
            
            // Apply syntax highlighting
            escapedLine = escapedLine
                // Keys - quoted strings followed by colon
                .replace(/^(\s*)("(?:[^"\\]|\\.)*")\s*:/g, '$1<span class="json-key">$2</span><span class="json-punctuation">:</span>')
                // String values - quoted strings
                .replace(/:\s*("(?:[^"\\]|\\.)*")/g, ': <span class="json-string">$1</span>')
                // Boolean values
                .replace(/:\s*(true|false)\b/g, ': <span class="json-boolean">$1</span>')
                // Null values
                .replace(/:\s*(null)\b/g, ': <span class="json-null">$1</span>')
                // Number values
                .replace(/:\s*(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b/g, ': <span class="json-number">$1</span>')
                // Standalone values in arrays
                .replace(/^(\s*)("(?:[^"\\]|\\.)*")(\s*,?\s*)$/g, '$1<span class="json-string">$2</span>$3')
                .replace(/^(\s*)(true|false)(\s*,?\s*)$/g, '$1<span class="json-boolean">$2</span>$3')
                .replace(/^(\s*)(null)(\s*,?\s*)$/g, '$1<span class="json-null">$2</span>$3')
                .replace(/^(\s*)(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(\s*,?\s*)$/g, '$1<span class="json-number">$2</span>$3')
                // Brackets, braces, and commas
                .replace(/([{}[\],])/g, '<span class="json-punctuation">$1</span>');
            
            return escapedLine;
        });
        
        return highlightedLines.join('\n');
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function copyJsonContent(event, contentId) {
        event.preventDefault();
        event.stopPropagation();
        
        const element = document.getElementById(contentId);
        if (element) {
            // Get the raw content from the data attribute
            let text = element.getAttribute('data-raw-content');
            const isTruncated = element.getAttribute('data-truncated') === 'true';
            const truncationInfo = element.getAttribute('data-truncation-info');
            
            if (!text) {
                // Fallback to text content if data attribute is not available
                text = element.textContent || element.innerText;
                text = text.replace(/^Copy\s*/, '').replace(/Copy$/, '').trim();
            }
            
            // Try to parse and re-stringify to ensure clean JSON formatting
            try {
                const parsed = JSON.parse(text);
                text = JSON.stringify(parsed, null, 2);
            } catch (e) {
                // If not valid JSON, just use the text as-is
                console.log('Content is not valid JSON, copying as-is');
            }
            
            // Add truncation warning to copied content if applicable
            if (isTruncated && truncationInfo) {
                text = `// ${truncationInfo}\n// Note: This content has been truncated for performance reasons\n\n${text}`;
            }
            
            navigator.clipboard.writeText(text).then(() => {
                const btn = event.target;
                const originalText = btn.textContent;
                const originalBg = btn.style.background;
                
                // Show success feedback
                btn.textContent = isTruncated ? '✓ Copied (Truncated)' : '✓ Copied!';
                btn.style.background = 'rgba(56, 161, 105, 0.9)';
                
                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.background = originalBg;
                }, 2000);
                
                console.log('📋 Content copied to clipboard' + (isTruncated ? ' (truncated)' : ''));
            }).catch(err => {
                console.error('❌ Failed to copy content:', err);
                
                // Show error feedback
                const btn = event.target;
                const originalText = btn.textContent;
                const originalBg = btn.style.background;
                
                btn.textContent = '❌ Failed';
                btn.style.background = 'rgba(229, 62, 62, 0.9)';
                
                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.background = originalBg;
                }, 2000);
            });
        }
    }

    function initWebSocket() {
        console.log('🔌 Initializing WebSocket connection...');
        
        if (ws) {
            ws.close();
        }
        
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        console.log(`🌐 Connecting to: ${wsUrl}`);
        
        ws = new WebSocket(wsUrl);
        
        ws.onopen = function() {
            console.log('✅ WebSocket connected successfully');
            wsConnected = true;
            updateConnectionStatus();
            if (wsReconnectTimeout) {
                clearTimeout(wsReconnectTimeout);
                wsReconnectTimeout = null;
            }
        };
        
        ws.onmessage = function(event) {
            try {
                const data = JSON.parse(event.data);
                console.log(`📨 WebSocket message received: ${data.type}`);
                if (data.type === 'init') {
                    logs = data.logs || [];
                    console.log(`🎬 Initial logs loaded: ${logs.length} items`);
                    processLogs();
                } else if (data.type === 'log') {
                    logs.push(data.log);
                    console.log(`➕ New log added, total: ${logs.length}`);
                    processLogs();
                }
            } catch (e) {
                console.error('❌ Error parsing WebSocket message:', e);
            }
        };
        
        ws.onclose = function(event) {
            console.log(`🔌 WebSocket disconnected (code: ${event.code}, reason: ${event.reason})`);
            wsConnected = false;
            updateConnectionStatus();
            // Reconnect after 3 seconds
            console.log('⏳ Will reconnect in 3 seconds...');
            wsReconnectTimeout = setTimeout(initWebSocket, 3000);
        };
        
        ws.onerror = function(error) {
            console.error('❌ WebSocket error:', error);
            wsConnected = false;
            updateConnectionStatus();
        };
    }

    function updateConnectionStatus() {
        const dot = document.getElementById('wsDot');
        const text = document.getElementById('wsText');
        if (wsConnected) {
            dot.className = 'live-dot live';
            text.className = 'live-label live';
            text.textContent = 'Live';
        } else {
            dot.className = 'live-dot offline';
            text.className = 'live-label offline';
            text.textContent = 'Offline';
        }
    }

    function processLogs() {
        console.log(`📊 Processing ${logs.length} logs...`);
        allTransactions = groupLogsIntoTransactions(logs);
        console.log(`📦 Grouped into ${allTransactions.length} transactions`);
        applyFilters();
        console.log(`🔍 Filtered to ${filteredTransactions.length} transactions`);
        updateStats();
        
        // Generate a hash of current data to detect actual changes
        const currentDataHash = JSON.stringify(filteredTransactions.map(t => ({
            id: t.id,
            method: t.method,
            url: t.url,
            status: getStatusCode(t),
            timestamp: t.timestamp
        })));
        
        // Only update table if data actually changed
        if (currentDataHash !== lastDataHash) {
            console.log('📊 Data changed...');
            lastDataHash = currentDataHash;
            
            if (!userInteracting) {
                console.log('✅ Updating table immediately');
                updateTable();
                pendingUpdates = false;
            } else {
                console.log('🛡️ User is interacting - marking update as pending');
                pendingUpdates = true;
                // Don't update the table at all - just mark that we have pending updates
            }
        } else {
            console.log('📊 No data changes detected, skipping table update');
        }
    }

    function groupLogsIntoTransactions(logs) {
        const transactions = new Map();
        
        logs.forEach(log => {
            // Use the transactionId if available, otherwise fall back to the old method
            let transactionId = log.transactionId;
            
            if (!transactionId) {
                // Fallback for logs without transactionId (backwards compatibility)
                const baseKey = `${log.method || 'GET'}_${log.url || log.uri}`;
                const timestamp = log.timestamp;
                
                // Find if there's an existing transaction for this request within 100ms window
                for (const [key, transaction] of transactions) {
                    if (key.startsWith(baseKey) && 
                        Math.abs(new Date(transaction.timestamp) - new Date(timestamp)) < 100) {
                        transactionId = key;
                        break;
                    }
                }
                
                // If no matching transaction found, create a new one
                if (!transactionId) {
                    transactionId = `${baseKey}_${timestamp}_${Math.random().toString(36).substr(2, 5)}`;
                }
            }
            
            // Get or create transaction
            if (!transactions.has(transactionId)) {
                transactions.set(transactionId, {
                    id: transactionId,
                    method: log.method || 'GET',
                    url: log.url || log.uri || '',
                    timestamp: log.timestamp,
                    request: null,
                    response: null,
                    error: null
                });
            }
            
            const transaction = transactions.get(transactionId);
            
            // Update transaction with log data
            if (log.type === 'request') {
                transaction.request = log;
                // Use request timestamp as the primary timestamp
                transaction.timestamp = log.timestamp;
                transaction.method = log.method || transaction.method;
                transaction.url = log.url || log.uri || transaction.url;
            } else if (log.type === 'response') {
                transaction.response = log;
                // Keep the earliest timestamp (usually from request)
                if (!transaction.timestamp || log.timestamp < transaction.timestamp) {
                    transaction.timestamp = log.timestamp;
                }
            } else if (log.type === 'error') {
                transaction.error = log;
                // Keep the earliest timestamp (usually from request)
                if (!transaction.timestamp || log.timestamp < transaction.timestamp) {
                    transaction.timestamp = log.timestamp;
                }
            }
        });
        
        return Array.from(transactions.values()).sort((a, b) => 
            new Date(b.timestamp) - new Date(a.timestamp)
        );
    }

    function applyFilters() {
        const searchTerm = document.getElementById('searchInput').value.toLowerCase();
        const methodFilter = document.getElementById('methodFilter').value;
        const statusFilter = document.getElementById('statusFilter').value;
        
        filteredTransactions = allTransactions.filter(transaction => {
            // Search filter
            if (searchTerm) {
                const searchText = `${transaction.method} ${transaction.url} ${getStatusCode(transaction)}`.toLowerCase();
                if (!searchText.includes(searchTerm)) return false;
            }
            
            // Method filter
            if (methodFilter && transaction.method !== methodFilter) {
                return false;
            }
            
            // Status filter
            if (statusFilter) {
                const statusCode = getStatusCode(transaction);
                if (statusFilter === '2xx' && !statusCode.match(/^2\d\d$/)) return false;
                if (statusFilter === '4xx' && !statusCode.match(/^4\d\d$/)) return false;
                if (statusFilter === '5xx' && !statusCode.match(/^5\d\d$/)) return false;
            }
            
            return true;
        });
    }

    function updateStats() {
        document.getElementById('logCount').textContent = allTransactions.length;
        document.getElementById('requestCount').textContent = allTransactions.length;
        document.getElementById('errorCount').textContent = 
            allTransactions.filter(t => t.error || (t.response && parseInt(getStatusCode(t)) >= 400)).length;
        document.getElementById('lastUpdated').textContent = new Date().toLocaleTimeString();
    }

    function updateTable() {
        console.log(`🔄 Updating table with ${filteredTransactions.length} transactions`);
        const tbody = document.getElementById('logsTableBody');
        
        // Save current expanded state before updating
        const currentlyExpandedSections = {};
        Object.keys(sectionExpandedState).forEach(key => {
            if (sectionExpandedState[key]) {
                currentlyExpandedSections[key] = true;
            }
        });
        
        if (filteredTransactions.length === 0) {
            if (logs.length === 0) {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 20px; color: #718096;">
                            🚀 Waiting for network requests...<br>
                            <small>Make HTTP requests in your app to see them here</small>
                        </td>
                    </tr>
                `;
            } else {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 20px; color: #718096;">
                            🔍 No logs match your current filters<br>
                            <small>Try adjusting your search or filter criteria</small>
                        </td>
                    </tr>
                `;
            }
            return;
        }
        
        let html = '';
        filteredTransactions.forEach((transaction, index) => {
            const isExpanded = expandedRows.has(transaction.id);
            const statusCode = getStatusCode(transaction);
            const rowClass = isExpanded ? 'expanded' : '';
            
            // Determine transaction type for display
            let transactionType = 'Pending';
            let typeClass = 'type-request';
            
            if (transaction.error) {
                transactionType = 'Failed';
                typeClass = 'type-error';
            } else if (transaction.response) {
                transactionType = 'Completed';
                typeClass = 'type-response';
            } else if (transaction.request) {
                transactionType = 'Pending';
                typeClass = 'type-request';
            }
            
            html += `
                <tr class="${rowClass}" onclick="toggleRow('${transaction.id}')">
                    <td>${isExpanded ? '▼' : '▶'}</td>
                    <td><span class="type-badge ${typeClass}">${transactionType}</span></td>
                    <td><span class="method ${transaction.method}">${transaction.method}</span></td>
                    <td><span class="url">${escapeHtml(transaction.url)}</span></td>
                    <td><span class="status-code ${getStatusClass(statusCode)}">${statusCode}</span></td>
                    <td><span class="timestamp">${new Date(transaction.timestamp).toLocaleTimeString()}</span></td>
                </tr>
            `;
            
            if (isExpanded) {
                html += `
                    <tr class="details-row expanded">
                        <td colspan="6">
                            <div class="details-content">
                                ${createDetailedView(transaction)}
                            </div>
                        </td>
                    </tr>
                `;
            }
        });
        
        tbody.innerHTML = html;
        
        // Restore expanded state for inner sections after DOM update
        setTimeout(() => {
            Object.keys(currentlyExpandedSections).forEach(key => {
                if (currentlyExpandedSections[key]) {
                    const [transactionId, section] = key.split('_');
                    const contentId = `content_${transactionId}_${section}`;
                    const element = document.getElementById(contentId);
                    const button = element ? element.parentElement.querySelector('.expand-btn') : null;
                    
                    if (element && button) {
                        element.style.maxHeight = 'none';
                        element.style.opacity = '1';
                        button.textContent = 'Collapse';
                        sectionExpandedState[key] = true;
                        console.log(`🔄 Restored expanded state for: ${key}`);
                    }
                }
            });
        }, 50); // Small delay to ensure DOM is updated
        
        console.log(`✅ Table updated successfully`);
    }

    function toggleRow(transactionId) {
        userInteracting = true;
        clearTimeout(interactionTimeout);
        
        if (expandedRows.has(transactionId)) {
            expandedRows.delete(transactionId);
        } else {
            expandedRows.add(transactionId);
        }
        
        updateTable();
        
        interactionTimeout = setTimeout(() => {
            userInteracting = false;
        }, 1000);
    }

    function refreshLogs() {
        console.log('📡 Fetching logs from server...');
        const loadingMessage = document.getElementById('logsTableBody');
        
        fetch('/logs')
            .then(response => {
                console.log(`📨 Server response: ${response.status}`);
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
                return response.json();
            })
            .then(data => {
                console.log(`✅ Received ${data.logs?.length || 0} logs from server`);
                logs = data.logs || [];
                processLogs();
                
                // Show success feedback
                const lastUpdated = document.getElementById('lastUpdated');
                if (lastUpdated) {
                    lastUpdated.textContent = new Date().toLocaleTimeString();
                }
            })
            .catch(error => {
                console.error('❌ Error fetching logs:', error);
                
                // Show error in the table if no logs are available
                if (logs.length === 0) {
                    loadingMessage.innerHTML = `
                        <tr>
                            <td colspan="6" style="text-align: center; color: #e53e3e; padding: 20px;">
                                ❌ Failed to load logs: ${error.message}<br>
                                <small>Check if the server is running and try refreshing the page</small>
                            </td>
                        </tr>
                    `;
                }
            });
    }

    function clearLogs() {
        if (confirm('Are you sure you want to clear all logs?')) {
            fetch('/logs/clear', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    logs = [];
                    processLogs();
                    console.log('Logs cleared');
                })
                .catch(error => {
                    console.error('Error clearing logs:', error);
                });
        }
    }

    // Event listeners
    document.addEventListener('DOMContentLoaded', function() {
        console.log('🎯 Dashboard DOM loaded, initializing...');
        
        // Search and filter event listeners
        document.getElementById('searchInput').addEventListener('input', applyFiltersAndUpdate);
        document.getElementById('methodFilter').addEventListener('change', applyFiltersAndUpdate);
        document.getElementById('statusFilter').addEventListener('change', applyFiltersAndUpdate);
        
        // Scroll detection
        window.addEventListener('scroll', function() {
            isScrolling = true;
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
                isScrolling = false;
            }, 500);
        });
        
        // Initial load
        refreshLogs();
        initWebSocket();
        
        // Auto refresh every 15 seconds only if WebSocket is disconnected and user not interacting
        setInterval(() => {
            if (!userInteracting && !isScrolling && !wsConnected) {
                console.log('🔄 Auto-refreshing logs (WebSocket disconnected)...');
                refreshLogs();
            }
        }, 15000);
        
        console.log('✅ Dashboard initialization complete');
    });

    function applyFiltersAndUpdate() {
        // Only update if user is not interacting with expanded content
        if (!userInteracting) {
            applyFilters();
            updateTable();
        } else {
            console.log('👤 Skipping filter update: user is interacting');
            // Just apply filters without updating table
            applyFilters();
        }
    }

    // Make functions globally available for onclick handlers
    window.toggleRow = toggleRow;
    window.toggleSection = toggleSection;
    window.copyJsonContent = copyJsonContent;
    window.copyCurlCommand = copyCurlCommand;
    window.refreshLogs = refreshLogs;
    window.clearLogs = clearLogs;
    window.forceRefreshNow = forceRefreshNow;
  ''';
  }
}

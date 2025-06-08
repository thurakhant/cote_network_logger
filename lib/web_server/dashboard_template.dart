/// HTML template for the network logger dashboard.
///
/// This template serves as a container for the Flutter web app.
class DashboardTemplate {
  /// Returns the complete HTML content for the dashboard.
  static String getHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Logger Dashboard</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #ec4899 100%);
            color: #1f2937;
            overflow-x: hidden;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 24px;
            min-height: 100vh;
        }
        
        .header {
            text-align: center;
            margin-bottom: 32px;
            color: white;
        }
        
        .header h1 {
            font-size: 2.75rem;
            margin: 0;
            font-weight: 700;
            text-shadow: 0 4px 8px rgba(0,0,0,0.2);
            letter-spacing: -0.025em;
        }
        
        .header p {
            margin: 12px 0 0 0;
            opacity: 0.95;
            font-size: 1.125rem;
            font-weight: 400;
        }
        
        .dashboard {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(20px);
            border-radius: 20px;
            box-shadow: 0 25px 50px rgba(0,0,0,0.15);
            border: 1px solid rgba(255, 255, 255, 0.2);
            overflow: hidden;
            min-height: 700px;
        }
        
        .controls {
            padding: 24px;
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            border-bottom: 1px solid rgba(226, 232, 240, 0.8);
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
            align-items: center;
        }
        
        .search-input {
            flex: 1;
            min-width: 250px;
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 500;
            background: white;
            transition: all 0.2s ease;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .search-input:focus {
            outline: none;
            border-color: #6366f1;
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
            transform: translateY(-1px);
        }
        
        .filter-select {
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 500;
            background: white;
            cursor: pointer;
            transition: all 0.2s ease;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .filter-select:hover {
            border-color: #6366f1;
            transform: translateY(-1px);
        }
        
        .stats {
            display: flex;
            gap: 12px;
            align-items: center;
            margin-left: auto;
        }
        
        .stat-item {
            text-align: center;
            padding: 12px 16px;
            border-radius: 12px;
            background: white;
            border: 1px solid rgba(226, 232, 240, 0.6);
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            min-width: 80px;
            transition: all 0.2s ease;
        }
        
        .stat-item:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        
        .stat-value {
            font-weight: 700;
            font-size: 20px;
            color: #6366f1;
            line-height: 1;
        }
        
        .stat-label {
            font-size: 11px;
            font-weight: 600;
            color: #64748b;
            margin-top: 4px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .connection-status {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 16px;
            border-radius: 20px;
            background: rgba(248, 250, 252, 0.8);
            border: 1px solid rgba(226, 232, 240, 0.6);
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        
        .live-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #ef4444;
            box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.2);
        }
        
        .live-dot.live {
            background: #10b981;
            box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0% { 
                opacity: 1; 
                box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
            }
            50% { 
                opacity: 0.8; 
                box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.1);
            }
            100% { 
                opacity: 1; 
                box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
            }
        }
        
        .live-label {
            font-size: 12px;
            font-weight: 600;
            color: #ef4444;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .live-label.live {
            color: #10b981;
        }
        
        .logs-container {
            padding: 24px;
            max-height: 650px;
            overflow-y: auto;
            background: #fafbfc;
        }
        
        .log-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .log-table th {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            padding: 16px 12px;
            text-align: left;
            font-weight: 700;
            font-size: 12px;
            color: #475569;
            border-bottom: 1px solid #e2e8f0;
            position: sticky;
            top: 0;
            z-index: 10;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .log-table td {
            padding: 16px 12px;
            border-bottom: 1px solid #f1f5f9;
            vertical-align: middle;
            font-size: 14px;
        }
        
        .log-table tr:hover {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 50%);
        }
        
        .log-table tr.expanded {
            background: #e3f2fd;
        }
        
        .type-badge {
            padding: 3px 6px;
            border-radius: 3px;
            font-size: 10px;
            font-weight: bold;
            text-transform: uppercase;
        }
        
        .type-request { background: #cce5ff; color: #004085; }
        .type-response { background: #d4edda; color: #155724; }
        .type-error { background: #f8d7da; color: #721c24; }
        
        .url {
            font-family: monospace;
            font-size: 11px;
        }
        
        .details-content {
            padding: 24px;
            background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
            border-radius: 12px;
            margin: 12px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }
        
        .method-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            text-align: center;
            min-width: 50px;
        }
        
        .GET { background: #d4edda; color: #155724; }
        .POST { background: #cce5ff; color: #004085; }
        .PUT { background: #ffe4b5; color: #856404; }
        .DELETE { background: #f8d7da; color: #721c24; }
        .PATCH { background: #e2e3e5; color: #383d41; }
        
        .status-code {
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 12px;
            text-align: center;
            min-width: 40px;
        }
        
        .status-2xx { background: #d4edda; color: #155724; }
        .status-3xx { background: #cce5ff; color: #004085; }
        .status-4xx { background: #ffe4b5; color: #856404; }
        .status-5xx { background: #f8d7da; color: #721c24; }
        
        .url-cell {
            max-width: 300px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        
        .timestamp {
            font-size: 11px;
            color: #6c757d;
            white-space: nowrap;
        }
        
        .details-row {
            display: none;
        }
        
        .details-row.expanded {
            display: table-row;
        }
        
        .details-cell {
            padding: 20px !important;
            background: #f8f9fa;
            border-left: 4px solid #667eea;
        }
        
        .transaction-overview {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            border: 1px solid #e9ecef;
        }
        
        .overview-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        
        .overview-item {
            padding: 10px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        
        .expandable-section {
            margin: 16px 0;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        
        .expandable-header {
            padding: 16px 20px;
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: all 0.2s ease;
            border-bottom: 1px solid transparent;
        }
        
        .expandable-header:hover {
            background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
            border-bottom-color: #e2e8f0;
        }
        
        .expandable-header h5 {
            margin: 0;
            display: flex;
            align-items: center;
            gap: 10px;
            font-weight: 600;
            color: #374151;
            font-size: 14px;
        }
        
        .expand-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 11px;
            font-weight: 600;
            color: #6366f1;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .expand-arrow {
            transition: transform 0.2s ease;
            font-size: 12px;
        }
        
        .expand-arrow.expanded {
            transform: rotate(90deg);
        }
        
        .expandable-content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease-out;
            background: white;
        }
        
        .expandable-content.expanded {
            max-height: 800px;
            overflow-y: auto;
        }
        
        .json-container {
            padding: 20px;
            position: relative;
        }
        
        .json-content {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 16px 50px 16px 16px;
            font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
            font-size: 13px;
            line-height: 1.5;
            white-space: pre-wrap;
            overflow-x: auto;
            position: relative;
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
        }
        
        .copy-btn {
            position: absolute;
            top: 12px;
            right: 12px;
            padding: 6px 12px;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
            box-shadow: 0 1px 3px rgba(99, 102, 241, 0.2);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .copy-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 2px 6px rgba(99, 102, 241, 0.3);
        }
        
        .content-preview {
            padding: 10px 15px;
            font-size: 11px;
            color: #6c757d;
            background: #fafafa;
            border-top: 1px solid #e9ecef;
        }
        
        .json-key { color: #d73a49; font-weight: bold; }
        .json-string { color: #032f62; }
        .json-number { color: #005cc5; }
        .json-boolean { color: #d73a49; }
        .json-null { color: #6f42c1; }
        .json-punctuation { color: #24292e; }
        
        .no-logs {
            text-align: center;
            padding: 40px;
            color: #6c757d;
        }
        
        .refresh-btn {
            padding: 12px 20px;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            transition: all 0.2s ease;
            box-shadow: 0 2px 4px rgba(99, 102, 241, 0.2);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
        }
        
        .refresh-btn:active {
            transform: translateY(0);
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 16px;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .header p {
                font-size: 1rem;
            }
            
            .controls {
                flex-direction: column;
                align-items: stretch;
                gap: 12px;
            }
            
            .search-input {
                min-width: 100%;
            }
            
            .stats {
                margin-left: 0;
                justify-content: space-between;
                gap: 8px;
            }
            
            .stat-item {
                min-width: 70px;
                padding: 8px 12px;
            }
            
            .stat-value {
                font-size: 16px;
            }
            
            .overview-grid {
                grid-template-columns: 1fr;
            }
            
            .log-table {
                font-size: 12px;
            }
            
            .log-table th,
            .log-table td {
                padding: 12px 8px;
            }
            
            .url-cell {
                max-width: 120px;
            }
            
            .expandable-header {
                padding: 12px 16px;
            }
            
            .json-container {
                padding: 16px;
            }
            
            .json-content {
                font-size: 11px;
                padding: 12px 40px 12px 12px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Network Logger Dashboard</h1>
            <p>Real-time HTTP monitoring for your Flutter app</p>
        </div>
        
        <div class="dashboard">
            <div class="controls">
                <input type="text" id="searchInput" class="search-input" placeholder="Search by URL, method, or status..." />
                
                <select id="methodFilter" class="filter-select">
                    <option value="">All Methods</option>
                    <option value="GET">GET</option>
                    <option value="POST">POST</option>
                    <option value="PUT">PUT</option>
                    <option value="DELETE">DELETE</option>
                    <option value="PATCH">PATCH</option>
                </select>
                
                <select id="statusFilter" class="filter-select">
                    <option value="">All Status</option>
                    <option value="2xx">2xx Success</option>
                    <option value="4xx">4xx Client Error</option>
                    <option value="5xx">5xx Server Error</option>
                </select>
                
                <button class="refresh-btn" onclick="forceRefreshNow()">🔄 Refresh</button>
                
                <div class="stats">
                    <div class="stat-item">
                        <div class="stat-value" id="logCount">0</div>
                        <div class="stat-label">Total</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="requestCount">0</div>
                        <div class="stat-label">Requests</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="errorCount">0</div>
                        <div class="stat-label">Errors</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="lastUpdated">--:--:--</div>
                        <div class="stat-label">Last Updated</div>
                    </div>
                </div>
                
                <div class="connection-status">
                    <span class="live-dot" id="wsDot"></span>
                    <span class="live-label" id="wsText">Connecting...</span>
                </div>
            </div>
            
            <div class="logs-container">
                <table class="log-table">
                    <thead>
                        <tr>
                            <th style="width: 30px;"></th>
                            <th style="width: 80px;">Type</th>
                            <th style="width: 80px;">Method</th>
                            <th>URL</th>
                            <th style="width: 80px;">Status</th>
                            <th style="width: 100px;">Time</th>
                        </tr>
                    </thead>
                    <tbody id="logsTableBody">
                        <tr>
                            <td colspan="6" style="text-align: center; padding: 20px; color: #718096;">
                                🚀 Connecting to server...<br>
                                <small>Initializing network logger</small>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    
    <script>
    {{DASHBOARD_SCRIPT}}
    
    // Initialize the dashboard
    document.addEventListener('DOMContentLoaded', function() {
        console.log('🎯 Dashboard initialized {{TIMESTAMP}}');
        initWebSocket();
        
        // Set up event listeners
        document.getElementById('searchInput').addEventListener('input', () => {
            applyFilters();
            updateTable();
        });
        
        document.getElementById('methodFilter').addEventListener('change', () => {
            applyFilters();
            updateTable();
        });
        
        document.getElementById('statusFilter').addEventListener('change', () => {
            applyFilters();
            updateTable();
        });
        
        // Initial empty state
        updateTable();
    });
    </script>
</body>
</html>
''';
  }
}

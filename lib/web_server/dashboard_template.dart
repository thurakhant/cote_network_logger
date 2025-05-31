/// HTML template for the network logger dashboard.
///
/// This template provides a beautiful, Material Design-inspired interface
/// for viewing network logs in real-time.
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
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Inter', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #2d3748;
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .dashboard-container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.98);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: #2d3748;
            padding: 24px;
            text-align: center;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            margin-bottom: 24px;
            position: relative;
        }
        
        .header h1 {
            font-size: 28px;
            font-weight: 700;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 6px;
            line-height: 1.2;
        }
        
        .header p {
            color: #718096;
            font-size: 16px;
            margin: 0;
        }
        
        .live-status {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            font-size: 18px;
            font-weight: 700;
            margin-left: 18px;
            vertical-align: middle;
        }
        
        .live-dot {
            display: inline-block;
            width: 18px;
            height: 18px;
            border-radius: 50%;
            background: #e53e3e;
            box-shadow: 0 0 8px #e53e3e44;
            transition: background 0.3s;
        }
        
        .live-dot.live {
            background: #38a169;
            box-shadow: 0 0 12px #38a16988;
        }
        
        .live-dot.offline {
            background: #e53e3e;
            box-shadow: 0 0 12px #e53e3e88;
        }
        
        .live-label {
            font-size: 18px;
            font-weight: 700;
            color: #2d3748;
        }
        
        .live-label.live {
            color: #38a169;
        }
        
        .live-label.offline {
            color: #e53e3e;
        }
        
        .controls {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 16px;
            border-radius: 12px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
            margin-bottom: 20px;
        }
        
        .controls-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 12px;
        }
        
        .stats {
            display: flex;
            gap: 16px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .stat {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            padding: 8px 14px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            border: 1px solid #e2e8f0;
        }
        
        .stat strong {
            color: #667eea;
            font-size: 16px;
        }
        
        .button-group {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 12px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
            box-shadow: 0 4px 16px rgba(102, 126, 234, 0.3);
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
        }
        
        .btn.danger {
            background: linear-gradient(135deg, #e53e3e 0%, #c53030 100%);
            box-shadow: 0 4px 16px rgba(229, 62, 62, 0.3);
        }
        
        .btn.danger:hover {
            box-shadow: 0 8px 24px rgba(229, 62, 62, 0.4);
        }
        
        .search-filter {
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .search-input {
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            width: 250px;
            transition: all 0.3s ease;
            background: white;
        }
        
        .search-input:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .filter-select {
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            background: white;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .filter-select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 12px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
            overflow: hidden;
        }
        
        .table-container {
            overflow-x: auto;
            overflow-y: visible;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            table-layout: fixed;
        }
        
        th, td {
            padding: 12px 16px;
            text-align: left;
            border-bottom: 1px solid #f1f5f9;
            overflow: hidden;
        }
        
        /* Specific column widths */
        th:nth-child(1), td:nth-child(1) { width: 30px; } /* Expand arrow */
        th:nth-child(2), td:nth-child(2) { width: 130px; } /* Transaction status */
        th:nth-child(3), td:nth-child(3) { width: 90px; } /* Method */
        th:nth-child(4), td:nth-child(4) { width: auto; min-width: 300px; } /* URL */
        th:nth-child(5), td:nth-child(5) { width: 80px; } /* Status */
        th:nth-child(6), td:nth-child(6) { width: 120px; } /* Time */
        
        th {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            font-weight: 600;
            color: #374151;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            position: sticky;
            top: 0;
            z-index: 10;
            border-bottom: 2px solid #e5e7eb;
        }
        
        tr {
            transition: all 0.2s ease;
            cursor: pointer;
        }
        
        tr:hover {
            background: rgba(102, 126, 234, 0.05);
        }
        
        tr.expanded {
            background: rgba(102, 126, 234, 0.08);
        }
        
        .type-badge {
            padding: 6px 12px;
            border-radius: 8px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .type-request {
            background: linear-gradient(135deg, #3182ce 0%, #2c5282 100%);
            color: white;
        }
        
        .type-response {
            background: linear-gradient(135deg, #38a169 0%, #2f855a 100%);
            color: white;
        }
        
        .type-error {
            background: linear-gradient(135deg, #e53e3e 0%, #c53030 100%);
            color: white;
        }
        
        .method {
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }
        
        .method.GET { background: #c6f6d5; color: #22543d; }
        .method.POST { background: #fed7aa; color: #9c4221; }
        .method.PUT { background: #bee3f8; color: #2a4365; }
        .method.DELETE { background: #fed7d7; color: #742a2a; }
        .method.PATCH { background: #e9d8fd; color: #553c9a; }
        
        .url {
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            font-size: 13px;
            max-width: 400px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            color: #4a5568;
        }
        
        .status-code {
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }
        
        .status-2xx { background: #c6f6d5; color: #22543d; }
        .status-3xx { background: #feebc8; color: #744210; }
        .status-4xx { background: #fed7d7; color: #742a2a; }
        .status-5xx { background: #e9d8fd; color: #553c9a; }
        
        .timestamp {
            font-size: 12px;
            color: #718096;
            white-space: nowrap;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
        }
        
        .details-row {
            background: #f8fafc;
            border-top: 1px solid #e5e7eb;
        }
        
        .details-row.expanded {
            background: #f8fafc;
        }
        
        .details-content {
            padding: 24px;
            background: #f8fafc;
        }
        
        .details-content h4 {
            color: #374151;
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 1px solid #e5e7eb;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .details-content h5 {
            color: #4b5563;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 8px;
            margin-top: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .content-section {
            margin-bottom: 24px;
            background: white;
            border-radius: 12px;
            padding: 16px;
            border: 1px solid #e5e7eb;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
        }
        
        .content-section h5 {
            color: #374151;
            font-size: 15px;
            font-weight: 700;
            margin-bottom: 12px;
            margin-top: 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding-bottom: 8px;
            border-bottom: 2px solid #f1f5f9;
        }
        
        /* JSON Syntax Highlighting */
        .json-content .json-key {
            color: #81e6d9;
            font-weight: 600;
        }
        
        .json-content .json-string {
            color: #68d391;
        }
        
        .json-content .json-number {
            color: #63b3ed;
            font-weight: 500;
        }
        
        .json-content .json-boolean {
            color: #f6ad55;
            font-weight: 600;
        }
        
        .json-content .json-null {
            color: #a0aec0;
            font-style: italic;
            font-weight: 500;
        }
        
        .json-content .json-punctuation {
            color: #cbd5e0;
            font-weight: 500;
        }
        
        /* JSON content styling - CONSOLIDATED */
        .json-content {
            background: linear-gradient(135deg, #1a202c 0%, #2d3748 100%);
            color: #e2e8f0;
            padding: 16px;
            border-radius: 8px;
            font-size: 12px;
            line-height: 1.6;
            border: 1px solid #4a5568;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            position: relative;
            overflow-x: auto;
            font-family: 'SF Mono', 'Monaco', 'Menlo', 'Consolas', monospace;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 350px;
            overflow-y: auto;
            margin: 0;
            tab-size: 2;
        }
        
        .json-content.collapsed {
            max-height: 150px;
            overflow: hidden;
            position: relative;
        }
        
        .json-content.collapsed::after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            height: 40px;
            background: linear-gradient(transparent, rgba(26, 32, 44, 0.95));
            pointer-events: none;
        }
        
        /* Improved scrollbar for JSON content */
        .json-content::-webkit-scrollbar {
            width: 6px;
            height: 6px;
        }
        
        .json-content::-webkit-scrollbar-track {
            background: #2d3748;
            border-radius: 3px;
        }
        
        .json-content::-webkit-scrollbar-thumb {
            background: #4a5568;
            border-radius: 3px;
        }
        
        .json-content::-webkit-scrollbar-thumb:hover {
            background: #5a67d8;
        }
        
        /* Status indicators */
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-success { background: #48bb78; }
        .status-error { background: #f56565; }
        .status-pending { background: #ed8936; }
        
        /* Transaction Overview Styles */
        .transaction-overview {
            background: white;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 16px;
            box-shadow: 0 1px 3px rgba(102, 126, 234, 0.08);
            border-left: 3px solid #667eea;
            border: 1px solid #e5e7eb;
        }
        
        .overview-grid {
            display: grid;
            grid-template-columns: 2fr 0.8fr 0.8fr 1.2fr;
            gap: 12px;
            margin-top: 10px;
        }
        
        .overview-item {
            background: #f8fafc;
            padding: 8px 12px;
            border-radius: 6px;
            border: 1px solid #e2e8f0;
            display: flex;
            flex-direction: column;
            gap: 3px;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
            min-height: 55px;
        }
        
        .overview-item strong {
            color: #4b5563;
            font-weight: 600;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .url-text {
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            color: #667eea;
            word-break: break-all;
            line-height: 1.3;
        }
        
        .method-badge {
            padding: 3px 6px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            background: #e6fffa;
            color: #234e52;
            display: inline-block;
            width: fit-content;
        }
        
        .status-code {
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            padding: 4px 10px;
            border-radius: 8px;
            font-size: 13px;
        }
        
        .status-2xx { background: #c6f6d5; color: #22543d; }
        .status-3xx { background: #feebc8; color: #744210; }
        .status-4xx { background: #fed7d7; color: #742a2a; }
        .status-5xx { background: #e9d8fd; color: #553c9a; }
        
        .timestamp {
            font-size: 13px;
            color: #718096;
            white-space: nowrap;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
        }
        
        /* Section Highlighting */
        .request-section {
            border-left: 3px solid #38a169;
            background: #f0fff4;
            margin-bottom: 16px;
            border-radius: 6px;
            padding: 14px;
            box-shadow: 0 1px 3px rgba(56, 161, 105, 0.1);
        }
        
        .response-section {
            border-left: 3px solid #3182ce;
            background: #ebf8ff;
            margin-bottom: 16px;
            border-radius: 6px;
            padding: 14px;
            box-shadow: 0 1px 3px rgba(49, 130, 206, 0.1);
        }
        
        .error-section {
            border-left: 3px solid #e53e3e;
            background: #fff5f5;
            margin-bottom: 16px;
            border-radius: 6px;
            padding: 14px;
            box-shadow: 0 1px 3px rgba(229, 62, 62, 0.1);
        }
        
        .details-content h4 {
            color: #374151;
            font-size: 15px;
            font-weight: 600;
            margin-bottom: 12px;
            padding-bottom: 6px;
            border-bottom: 1px solid #e5e7eb;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .details-content h5 {
            color: #4a5568;
            font-size: 15px;
            font-weight: 700;
            margin-bottom: 10px;
            margin-top: 18px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .content-section {
            margin-bottom: 22px;
        }
        
        /* Readable JSON + Copy Button */
        .json-content {
            background: linear-gradient(135deg, #1a202c 0%, #2d3748 100%);
            color: #e2e8f0;
            padding: 18px 16px 18px 40px;
            border-radius: 14px;
            font-size: 13px;
            line-height: 1.7;
            border: 1px solid #4a5568;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.13);
            position: relative;
            overflow-x: auto;
        }
        
        .copy-btn {
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(102, 126, 234, 0.8);
            color: white;
            border: none;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 10px;
            cursor: pointer;
            font-weight: 600;
            opacity: 0.7;
            transition: all 0.2s ease;
            z-index: 5;
            backdrop-filter: blur(10px);
        }
        
        .copy-btn:hover {
            background: rgba(102, 126, 234, 1);
            opacity: 1;
            transform: translateY(-1px);
        }
        
        /* Content preview when collapsed */
        .content-preview {
            font-size: 11px;
            color: #718096;
            font-style: italic;
            margin-top: 6px;
            padding: 6px 10px;
            background: #f7fafc;
            border-radius: 4px;
            border: 1px solid #e2e8f0;
        }
        
        /* Responsive tweaks */
        @media (max-width: 768px) {
            .header { 
                padding: 16px; 
                margin-bottom: 16px;
            }
            .header h1 {
                font-size: 24px;
            }
            .controls {
                padding: 12px;
            }
            .controls-row {
                flex-direction: column;
                align-items: stretch;
                gap: 12px;
            }
            .stats {
                justify-content: center;
                gap: 12px;
            }
            .button-group {
                justify-content: center;
            }
            .search-filter {
                flex-direction: column;
                gap: 8px;
            }
            .search-input,
            .filter-select {
                width: 100%;
            }
            .transaction-overview { 
                padding: 16px;
                margin-bottom: 16px;
            }
            .overview-grid { 
                grid-template-columns: 1fr 1fr;
                grid-template-rows: 1fr 1fr;
                gap: 12px; 
            }
            .overview-item { 
                padding: 8px 12px;
                min-height: 50px;
            }
            .details-content { 
                padding: 16px; 
            }
            .json-content { 
                font-size: 11px; 
                padding: 12px; 
            }
            th, td {
                padding: 8px 12px;
                font-size: 12px;
            }
        }
        
        @media (max-width: 480px) {
            .dashboard-container {
                padding: 12px;
            }
            .header h1 {
                font-size: 20px;
            }
            .live-status {
                font-size: 14px;
                margin-left: 8px;
            }
            .overview-item strong {
                font-size: 11px;
            }
            .url-text {
                font-size: 12px;
            }
        }
        
        /* Expandable content improvements */
        .expandable-section {
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            margin-bottom: 12px;
            overflow: hidden;
            transition: all 0.3s ease;
            background: white;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
        }
        
        .expandable-header {
            padding: 12px 16px;
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            border-bottom: 1px solid #e5e7eb;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: space-between;
            transition: all 0.2s ease;
            user-select: none;
        }
        
        .expandable-header:hover {
            background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
        }
        
        .expandable-header.collapsed {
            border-bottom: none;
        }
        
        .expandable-header h5 {
            margin: 0;
            font-size: 14px;
            font-weight: 600;
            color: #374151;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .expand-indicator {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            color: #6b7280;
            font-weight: 500;
        }
        
        .expand-arrow {
            transition: transform 0.3s ease;
            font-size: 12px;
            color: #667eea;
            font-weight: bold;
        }
        
        .expand-arrow.expanded {
            transform: rotate(90deg);
        }
        
        .expandable-content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.4s ease, padding 0.3s ease;
            padding: 0 16px;
        }
        
        .expandable-content.expanded {
            max-height: 2000px;
            padding: 16px;
        }
        
        .expandable-content.auto-height {
            max-height: none;
        }

        /* JSON content styling improvements */
        .json-container {
            position: relative;
            margin-top: 8px;
        }
        
        .json-expand-overlay {
            position: absolute;
            bottom: 8px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(102, 126, 234, 0.9);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 16px;
            font-size: 11px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s ease;
            backdrop-filter: blur(10px);
            z-index: 10;
        }
        
        .json-expand-overlay:hover {
            background: rgba(102, 126, 234, 1);
            transform: translateX(-50%) translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="dashboard-container">
        <div class="header">
            <h1>🚀 coTe Network Dashboard{{TIMESTAMP}}
                <span class="live-status">
                    <span id="wsDot" class="live-dot offline"></span>
                    <span id="wsText" class="live-label offline">Offline</span>
                </span>
            </h1>
            <p>Real-time HTTP activity monitoring</p>
        </div>
        
        <div class="controls">
            <div class="controls-row">
                <div class="stats">
                    <div class="stat">
                        <strong id="logCount">0</strong> Transactions
                    </div>
                    <div class="stat">
                        <strong id="requestCount">0</strong> Requests
                    </div>
                    <div class="stat">
                        <strong id="errorCount">0</strong> Errors
                    </div>
                    <div class="stat">
                        Last updated: <span id="lastUpdated">Never</span>
                    </div>
                </div>
                <div class="button-group">
                    <button class="btn" onclick="refreshLogs()">
                        🔄 Refresh
                    </button>
                    <button class="btn danger" onclick="clearLogs()">
                        🗑️ Clear All
                    </button>
                </div>
            </div>
            <div class="search-filter">
                <input type="text" class="search-input" id="searchInput" placeholder="🔍 Search URLs, methods, status codes...">
                <select class="filter-select" id="methodFilter">
                    <option value="">All Methods</option>
                    <option value="GET">GET</option>
                    <option value="POST">POST</option>
                    <option value="PUT">PUT</option>
                    <option value="DELETE">DELETE</option>
                    <option value="PATCH">PATCH</option>
                </select>
                <select class="filter-select" id="statusFilter">
                    <option value="">All Status</option>
                    <option value="2xx">2xx Success</option>
                    <option value="4xx">4xx Client Error</option>
                    <option value="5xx">5xx Server Error</option>
                </select>
            </div>
        </div>
        
        <div class="container">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th></th>
                            <th>Transaction</th>
                            <th>Method</th>
                            <th>URL</th>
                            <th>Status</th>
                            <th>Time</th>
                        </tr>
                    </thead>
                    <tbody id="logsTableBody">
                        <tr>
                            <td colspan="6" class="loading">🔄 Loading network logs...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        {{DASHBOARD_SCRIPT}}
    </script>
</body>
</html>
''';
  }
}

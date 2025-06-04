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
            width: 100vw;
            height: 100vh;
            overflow: hidden;
        }
        #flutter_target {
            width: 100%;
            height: 100%;
        }
    </style>
</head>
<body>
    <div id="flutter_target"></div>
    <script src="main.dart.js" type="application/javascript"></script>
</body>
</html>
''';
  }
}

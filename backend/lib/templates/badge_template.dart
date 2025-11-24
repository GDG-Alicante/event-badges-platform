String getBadgeHtmlTemplate() {
  return r"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Redirigiendo...</title>
    <script>
        // This will be a placeholder replaced by the backend
        const assertionUrl = "{{ASSERTION_URL}}";

        window.onload = function() {
            const url = new URL(window.location.href);
            
            // Dynamically find the base path (e.g., /open-badges)
            const basePath = url.pathname.substring(0, url.pathname.indexOf('/badges/'));

            // Construct the new URL with the assertion parameter
            const newUrl = `${url.origin}${basePath}/?assertion=${encodeURIComponent(assertionUrl)}`;
            
            window.location.href = newUrl;
        };
    </script>
</head>
<body>
    <p>Redirigiendo...</p>
</body>
</html>
""";
}

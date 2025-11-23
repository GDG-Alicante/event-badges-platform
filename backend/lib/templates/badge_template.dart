String getBadgeHtmlTemplate() {
  return r"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Redirigiendo...</title>
    <script>
        window.onload = function() {
            const url = new URL(window.location.href);
            const pathSegments = url.pathname.split('/');
            const certificateId = pathSegments.pop().replace('.html', '');
            const eventSlug = pathSegments[pathSegments.length - 2];
            window.location.href = `${url.origin}/?event=${eventSlug}&certificate=${certificateId}`;
        };
    </script>
</head>
<body>
    <p>Redirigiendo...</p>
</body>
</html>
""";
}

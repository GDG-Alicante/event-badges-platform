String getBadgeHtmlTemplate() {
  return r"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificado de Asistencia</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --color-blue: #4285F4;
            --color-red: #DB4437;
            --color-yellow: #F4B400;
            --color-green: #0F9D58;
            --color-grey: #f5f5f5;
            --text-dark: #333;
            --text-light: #757575;
        }
        body {
            font-family: 'Roboto', sans-serif;
            background-color: var(--color-grey);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            color: var(--text-dark);
        }
        .card {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            width: 90%;
            max-width: 600px;
            text-align: center;
            overflow: hidden;
            transition: all 0.3s ease;
        }
        .card-header {
            /* The background is now the image itself */
            padding: 0;
        }
        .issuer-logo {
            width: 100%;
            height: auto;
            display: block; /* To remove any extra space below the image */
        }
        .issuer-name {
            color: white;
            font-size: 1.5rem;
            font-weight: 500;
            margin: 0;
        }
        .card-body {
            padding: 32px;
        }
        .badge-image {
            max-width: 120px;
            border-radius: 50%;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 24px;
        }
        .badge-name {
            font-size: 1.8rem;
            font-weight: 700;
            margin: 0 0 8px 0;
        }
        .badge-description {
            font-size: 1rem;
            color: var(--text-light);
            margin: 0 0 24px 0;
        }
        .recipient-intro {
            font-size: 1rem;
            color: var(--text-light);
            margin: 0;
        }
        .recipient-name {
            font-size: 2rem;
            font-weight: 500;
            color: var(--color-blue);
            margin: 8px 0 24px 0;
        }
        .issue-date {
            font-size: 0.9rem;
            color: var(--text-light);
        }
        .card-footer {
            background-color: #fafafa;
            padding: 16px;
            border-top: 1px solid #e0e0e0;
            font-size: 0.8rem;
        }
        .verification-link {
            color: var(--color-blue);
            text-decoration: none;
            font-weight: 500;
        }
        .verification-link:hover {
            text-decoration: underline;
        }
        .how-to-use {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            width: 90%;
            max-width: 600px;
            text-align: left;
            padding: 24px;
            margin-top: 24px;
        }
        .how-to-use h3 {
            margin-top: 0;
            color: var(--color-blue);
        }
        .how-to-use ul {
            padding-left: 20px;
            line-height: 1.6;
        }
        .loading-state {
            padding: 48px;
            font-size: 1.2rem;
            color: var(--text-light);
        }
        .dot-flashing {
            position: relative;
            width: 10px;
            height: 10px;
            border-radius: 5px;
            background-color: var(--color-blue);
            color: var(--color-blue);
            animation: dotFlashing 1s infinite linear alternate;
            animation-delay: .5s;
            display: inline-block;
            margin: 0 4px;
        }
        .dot-flashing::before, .dot-flashing::after {
            content: '';
            display: inline-block;
            position: absolute;
            top: 0;
        }
        .dot-flashing::before {
            left: -15px;
            width: 10px;
            height: 10px;
            border-radius: 5px;
            background-color: var(--color-blue);
            color: var(--color-blue);
            animation: dotFlashing 1s infinite alternate;
            animation-delay: 0s;
        }
        .dot-flashing::after {
            left: 15px;
            width: 10px;
            height: 10px;
            border-radius: 5px;
            background-color: var(--color-blue);
            color: var(--color-blue);
            animation: dotFlashing 1s infinite alternate;
            animation-delay: 1s;
        }

        @keyframes dotFlashing {
            0% { background-color: var(--color-blue); }
            50%, 100% { background-color: rgba(66, 133, 244, 0.2); }
        }

    </style>
</head>
<body>

    <div class="card" id="certificate-card" style="display: none;">
            <div class="card-header">
                <img id="issuer-logo" src="" alt="Logo del Emisor" class="issuer-logo">
            </div>        <div class="card-body">
            <img id="badge-image" src="" alt="Imagen de la Insignia" class="badge-image">
            <h2 id="badge-name" class="badge-name"></h2>
            <p id="badge-description" class="badge-description"></p>
            <p class="recipient-intro">Certificado otorgado a:</p>
            <p class="recipient-name" id="recipient-name">{{RECIPIENT_NAME}}</p>
            <p class="issue-date" id="issue-date"></p>
        </div>
        <div class="card-footer">
            <a id="verification-link" href="#" class="verification-link" target="_blank">Verificar Credencial</a>
        </div>
    </div>

    <div class="how-to-use" id="how-to-use-card" style="display: none;">
        <h3>¿Dónde puedes usar esta insignia?</h3>
        <p>Esta es una Insignia Digital Abierta (Open Badge) que puedes gestionar y compartir en múltiples plataformas:</p>
        <ul>
            <li>Añádela como una credencial verificable a tu perfil de <strong>LinkedIn</strong>.</li>
            <li>Impórtala a "mochilas" de insignias como <strong>Open Badge Passport</strong>, <strong>Badgr</strong> o <strong>Credly</strong>.</li>
            <li>Compártela en tus redes sociales o página web.</li>
        </ul>
    </div>

    <div class="card" id="loading-card">
        <div class="loading-state">
            <p>Cargando certificado...</p>
            <div class="dot-flashing"></div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', async () => {
            const assertionUrl = window.location.href.replace('.html', '.json');
            
            const certificateCard = document.getElementById('certificate-card');
            const loadingCard = document.getElementById('loading-card');

            try {
                // 1. Fetch Assertion
                const assertionRes = await fetch(assertionUrl);
                if (!assertionRes.ok) throw new Error(`No se pudo cargar la aserción: ${assertionRes.statusText}`);
                const assertion = await assertionRes.json();

                // 2. Fetch BadgeClass
                const badgeUrl = assertion.badge;
                const badgeRes = await fetch(badgeUrl);
                if (!badgeRes.ok) throw new Error(`No se pudo cargar la insignia: ${badgeRes.statusText}`);
                const badge = await badgeRes.json();

                // 3. Fetch Issuer
                const issuerUrl = badge.issuer;
                const issuerRes = await fetch(issuerUrl);
                if (!issuerRes.ok) throw new Error(`No se pudo cargar el emisor: ${issuerRes.statusText}`);
                const issuer = await issuerRes.json();

                // 4. Populate HTML
                document.title = `Certificado: ${badge.name}`;
                
                // Issuer info
                document.getElementById('issuer-logo').src = issuer.image;
                document.getElementById('issuer-logo').alt = `Logo de ${issuer.name}`;
                // document.getElementById('issuer-name').textContent = issuer.name; // Removed as per new design

                // Badge info
                document.getElementById('badge-image').src = badge.image;
                document.getElementById('badge-image').alt = `Insignia de ${badge.name}`;
                document.getElementById('badge-name').textContent = badge.name;
                document.getElementById('badge-description').textContent = badge.description;

                // Recipient & Date
                // The name is not in the assertion, so we leave it generic or could be passed differently
                // For now, we will use a placeholder from the assertion if available, otherwise generic.
                // NOTE: The name is not part of the Open Badges standard assertion, which is why we can't get it here.
                // The original implementation had access to it, this new one does not. This is a trade-off.
                // The recipient name is now injected by the server.
                
                const issuedOn = new Date(assertion.issuedOn);
                document.getElementById('issue-date').textContent = `Emitido el ${issuedOn.toLocaleDateString('es-ES')}`;

                // Verification link
                document.getElementById('verification-link').href = assertionUrl;

                // Show card
                loadingCard.style.display = 'none';
                certificateCard.style.display = 'block';
                document.getElementById('how-to-use-card').style.display = 'block';

            } catch (error) {
                loadingCard.innerHTML = `<div class="loading-state"><p>Error al cargar el certificado:</p><p style="color: var(--color-red); font-size: 0.9rem;">${error.message}</p></div>`;
                console.error(error);
            }
        });
    </script>

</body>
</html>
""";
}
import 'dart:js_interop';
import 'package:web/web.dart';
import 'dart:convert';

const backendUrl =
    'https://gdg-event-badges-backend-264650654366.europe-west8.run.app';

void main() {
  final void Function(Event) domContentLoadedListener = (Event e) {
    _initializeFrontend();
  };

  if (document.readyState == 'complete' ||
      document.readyState == 'interactive') {
    _initializeFrontend();
  } else {
    window.addEventListener('DOMContentLoaded', domContentLoadedListener.toJS);
  }
}

Element querySelector(String selector) {
  final element = document.querySelector(selector);
  if (element == null) {
    throw Exception('Could not find element with selector: $selector');
  }
  return element;
}

void _initializeFrontend() {
  try {
    // --- Get references to all needed DOM elements ---
    final claimView = querySelector('#claim-view') as HTMLDivElement;
    final thankYouView = querySelector('#thank-you-view') as HTMLDivElement;
    final certificateView =
        querySelector('#certificate-view') as HTMLDivElement;
    final form = querySelector('#claim-form') as HTMLFormElement;
    final emailInput = querySelector('#email-input') as HTMLInputElement;
    final status = querySelector('#status') as HTMLDivElement;
    final submitButton = querySelector('#submit-button') as HTMLButtonElement;
    final eventSelector = querySelector('#event-selector') as HTMLSelectElement;
    final loadingIndicator =
        querySelector('#loading-indicator') as HTMLDivElement;
    final formContainer = querySelector('#form-container') as HTMLDivElement;
    final newClaimButton =
        querySelector('#new-claim-button') as HTMLButtonElement;
    final eventNameElement = querySelector('#event-name') as HTMLHeadingElement;
    final eventSelectorPlaceholder =
        querySelector('#event-selector-placeholder') as HTMLDivElement;

    // --- Initial State Setup ---
    thankYouView.style.display = 'none';
    claimView.style.display = 'block';
    certificateView.style.display = 'none';
    submitButton.disabled = true;

    // --- Event Loading & URL Parameter Logic ---
    final url = URL(window.location.href);
    final assertionUrlFromUrl = url.searchParams.get('assertion');

    final container = querySelector('.container');

    if (assertionUrlFromUrl != null) {
      // An assertion URL is present, so show the certificate view.
      container.classList.add('certificate-view-active');
      claimView.style.display = 'none';
      thankYouView.style.display = 'none';
      certificateView.style.display = 'block';
      _showCertificateView(assertionUrlFromUrl);
    } else {
      // No assertion URL, so proceed with the claim flow.
      final eventSlugFromUrl = url.searchParams.get('event');
      container.classList.remove('certificate-view-active');
      if (eventSlugFromUrl == null || eventSlugFromUrl.isEmpty) {
        // No event in URL, so show the event selector.
        loadingIndicator.style.display = 'block';
        formContainer.style.display = 'none';
        eventSelectorPlaceholder.style.display = 'block';
        eventNameElement.style.display = 'none';
        _loadAvailableEvents(
            eventSelector, loadingIndicator, formContainer, submitButton);
      } else {
        // An event slug is present in the URL, bypass the selector.
        loadingIndicator.style.display = 'none';
        formContainer.style.display = 'block';
        eventSelectorPlaceholder.style.display = 'none';
        eventNameElement.innerText =
            eventSlugFromUrl.replaceAll('-', ' ').toUpperCase(); // Simple format
        eventNameElement.style.display = 'block';
        submitButton.disabled = false;
      }

      // Setup form listener only if we are in the claim flow
      final void Function(Event) formSubmitListener = (Event e) {
        e.preventDefault();
        final finalEventSlug = eventSlugFromUrl ?? eventSelector.value;
        _handleFormSubmit(emailInput.value, finalEventSlug, status,
            submitButton, claimView, thankYouView, certificateView);
      };
      form.addEventListener('submit', formSubmitListener.toJS);
    }


  } catch (e) {
    window
        .alert('A fatal error occurred during initialization: ${e.toString()}');
  }
}

Future<void> _showCertificateView(String assertionUrl) async {
  try {
    // 1. Fetch Assertion
    final assertionRes = await window.fetch(assertionUrl.toJS).toDart;
    if (!assertionRes.ok)
      throw Exception('Could not load assertion: ${assertionRes.statusText}');
    final assertion = jsonDecode((await assertionRes.text().toDart).toDart)
        as Map<String, dynamic>;

    // 2. Fetch BadgeClass
    final badgeUrl = assertion['badge'] as String;
    final badgeRes = await window.fetch(badgeUrl.toJS).toDart;
    if (!badgeRes.ok)
      throw Exception('Could not load badge: ${badgeRes.statusText}');
    final badge = jsonDecode((await badgeRes.text().toDart).toDart)
        as Map<String, dynamic>;

    // 3. Fetch Issuer
    final issuerUrl = badge['issuer'] as String;
    final issuerRes = await window.fetch(issuerUrl.toJS).toDart;
    if (!issuerRes.ok)
      throw Exception('Could not load issuer: ${issuerRes.statusText}');
    final issuer = jsonDecode((await issuerRes.text().toDart).toDart)
        as Map<String, dynamic>;

    // 4. Populate HTML
    document.title = 'Certificate: ${badge['name']}';

    // Issuer info
    (querySelector('#issuer-logo') as HTMLImageElement).src =
        issuer['image'] as String;
    (querySelector('#issuer-logo') as HTMLImageElement).alt =
        'Logo for ${issuer['name']}';

    // Badge info
    (querySelector('#badge-image') as HTMLImageElement).src =
        badge['image'] as String;
    (querySelector('#badge-image') as HTMLImageElement).alt =
        'Badge for ${badge['name']}';
    querySelector('#badge-name').textContent = badge['name'] as String;
    querySelector('#badge-description').textContent =
        badge['description'] as String;



    final issuedOn = DateTime.parse(assertion['issuedOn'] as String);
    querySelector('#issue-date').textContent =
        'Issued on ${issuedOn.toLocal()}';

    // Verification link & copy functionality
    final assertionUrlInput =
        querySelector('.assertion-url-input') as HTMLInputElement;
    assertionUrlInput.value = assertionUrl;

    final copyUrlButton = querySelector('.copy-url-button') as HTMLButtonElement;
    final originalButtonContent = copyUrlButton.innerHTML;

    final void Function(Event) copyClickListener = (Event event) {
      window.navigator.clipboard.writeText(assertionUrl).toDart.then((_) {
        copyUrlButton.textContent = '¡Copiado!';
        Future.delayed(const Duration(seconds: 2), () {
          copyUrlButton.innerHTML = originalButtonContent;
        });
      }).catchError((e) {
        copyUrlButton.textContent = 'Error';
        print('Could not copy text: $e');
        Future.delayed(const Duration(seconds: 2), () {
          copyUrlButton.innerHTML = originalButtonContent;
        });
      });
    };

    copyUrlButton.addEventListener('click', copyClickListener.toJS);
  } catch (error) {
    querySelector('#certificate-view').innerHTML =
        '<div class="card"><div class="loading-state"><p>Error loading certificate:</p><p style="color: var(--color-red); font-size: 0.9rem;">${error.toString()}</p></div></div>'
            .toJS;
    print(error);
  }
}

Future<void> _loadAvailableEvents(
    HTMLSelectElement eventSelector,
    HTMLDivElement loadingIndicator,
    HTMLDivElement formContainer,
    HTMLButtonElement submitButton) async {
  try {
    final response = await window.fetch((backendUrl + '/events').toJS).toDart;
    final responseText = (await response.text().toDart).toDart;

    if (response.ok) {
      final events = jsonDecode(responseText) as List;
      if (events.isNotEmpty) {
        eventSelector.options.length = 0; // Clear previous options
        for (final event in events) {
          final eventMap = event as Map<String, dynamic>;
          final option = document.createElement('option') as HTMLOptionElement;
          option.value = eventMap['slug'] as String? ?? '';
          option.text = eventMap['name'] as String? ?? '';
          eventSelector.add(option);
        }
        loadingIndicator.style.display = 'none';
        formContainer.style.display = 'block';
        submitButton.disabled = false;
      } else {
        loadingIndicator.innerText = 'No se encontraron eventos disponibles.';
      }
    } else {
      loadingIndicator.innerText =
          'Error al cargar eventos: ${responseText.isNotEmpty ? responseText : response.statusText}';
    }
  } catch (e) {
    loadingIndicator.innerText =
        'Error de conexión con el servidor al cargar eventos.';
    print('Error in _loadAvailableEvents: $e'); // Add this line for debugging
  }
}

Future<void> _handleFormSubmit(
    String email,
    String eventSlug,
    HTMLDivElement status,
    HTMLButtonElement submitButton,
    HTMLDivElement claimView,
    HTMLDivElement thankYouView,
    HTMLDivElement certificateView) async {
  status.innerText = 'Verificando y generando tu insignia...';
  status.style.display = 'block';
  submitButton.disabled = true;

  try {
    final headers = Headers();
    headers.append('Content-Type', 'application/json');

    final response = await window
        .fetch(
          (backendUrl + '/claim').toJS,
          RequestInit(
            method: 'POST',
            headers: headers,
            body: jsonEncode({
              'email': email,
              'event_slug': eventSlug,
              'name': email, // Backend uses this email to find the real name
            }).toJS,
          ),
        )
        .toDart;

    final responseBody = (await response.text().toDart).toDart;

    void handleSuccess(String certificateUrl) {
      try {
        final uri = Uri.parse(certificateUrl);
        final githubOwner = uri.host.split('.').first;
        final pathSegments = uri.pathSegments;
        final githubRepo = pathSegments[0];
        final eventSlugFromUrl = pathSegments[2];

        _showThankYouScreen(certificateUrl, githubOwner, githubRepo,
            eventSlugFromUrl, thankYouView, certificateView, claimView);
      } catch (e) {
        status.innerText =
            'Error: No se pudo procesar la URL del certificado: $certificateUrl';
      }
    }

    if (response.ok) {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final certificateUrl = data['certificate_url'] as String?;
      if (certificateUrl != null) {
        handleSuccess(certificateUrl);
      } else {
        status.innerText =
            'Error: La respuesta del servidor no contenía una URL de certificado.';
      }
    } else if (response.status == 409) {
      // The backend returns a helpful HTML string with a link.
      // Set it directly as the innerHTML of the status element.
      status.innerHTML = responseBody.toJS;
    } else {
      String errorMessage;
      final statusText = response.statusText;
      if (responseBody.isNotEmpty) {
        errorMessage = responseBody;
      } else {
        errorMessage = statusText;
      }
      status.innerHTML = 'Error: $errorMessage'.toJS;
    }
  } catch (e) {
    status.innerText =
        'Error de conexión con el servidor, Inténtelo de nuevo más tarde.';
  } finally {
    submitButton.disabled = false;
  }
}

void _showThankYouScreen(
    String certificateUrl,
    String githubOwner,
    String githubRepo,
    String eventSlug,
    HTMLDivElement thankYouView,
    HTMLDivElement certificateView,
    HTMLDivElement claimView) {
  claimView.style.display = 'none';
  certificateView.style.display = 'none';
  thankYouView.style.display = 'block';

  // --- Logic for the new Copy Widget in the Thank You screen ---
  final thankYouAssertionUrlInput =
      thankYouView.querySelector('.assertion-url-input') as HTMLInputElement;
  thankYouAssertionUrlInput.value = certificateUrl;

  final thankYouCopyUrlButton =
      thankYouView.querySelector('.copy-url-button') as HTMLButtonElement;
  final originalButtonContent = thankYouCopyUrlButton.innerHTML;

  final void Function(Event) copyClickListener = (Event event) {
    window.navigator.clipboard.writeText(certificateUrl).toDart.then((_) {
      thankYouCopyUrlButton.textContent = '¡Copiado!';
      Future.delayed(const Duration(seconds: 2), () {
        thankYouCopyUrlButton.innerHTML = originalButtonContent;
      });
    }).catchError((e) {
      thankYouCopyUrlButton.textContent = 'Error';
      print('Could not copy text: $e');
      Future.delayed(const Duration(seconds: 2), () {
        thankYouCopyUrlButton.innerHTML = originalButtonContent;
      });
    });
  };
  thankYouCopyUrlButton.addEventListener('click', copyClickListener.toJS);

  // --- Logic for the "Check on Click" navigation button ---
  final viewBadgeButton =
      querySelector('#view-badge-button') as HTMLButtonElement;
  final thankYouStatus = querySelector('#thank-you-status') as HTMLDivElement;

  final void Function(Event) viewBadgeClickListener = (Event event) async {
    viewBadgeButton.disabled = true;
    thankYouStatus.textContent = 'Comprobando...';

    try {
      final response = await window.fetch(certificateUrl.toJS).toDart;
      if (response.ok) {
        thankYouStatus.textContent = '¡Listo! Redirigiendo...';
        window.location.href = certificateUrl;
      } else {
        thankYouStatus.textContent =
            'Aún no está lista, inténtalo de nuevo en un momento.';
        // Clear the message after a few seconds
        Future.delayed(const Duration(seconds: 3), () {
          thankYouStatus.textContent = '';
        });
      }
    } catch (e) {
      thankYouStatus.textContent = 'Error de red al comprobar el estado.';
      print('Error fetching certificate URL: $e');
    } finally {
      viewBadgeButton.disabled = false;
    }
  };

  viewBadgeButton.addEventListener('click', viewBadgeClickListener.toJS);
}
import 'dart:js_interop';
import 'package:web/web.dart';
import 'dart:convert';

const backendUrl =
    'https://gdg-event-badges-backend-264650654366.europe-west8.run.app';

void main() {
  if (document.readyState == 'complete' ||
      document.readyState == 'interactive') {
    _initializeFrontend();
  } else {
    window.addEventListener(
        'DOMContentLoaded',
        (Event e) {
          _initializeFrontend();
        }.toJS);
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
    // final mainTitle = querySelector('#main-title') as HTMLHeadingElement;
    final eventNameElement = querySelector('#event-name') as HTMLHeadingElement;
    final eventSelectorPlaceholder =
        querySelector('#event-selector-placeholder') as HTMLDivElement;

    // --- Initial State Setup ---
    thankYouView.style.display = 'none';
    claimView.style.display = 'block';
    submitButton.disabled = true;

    // --- Event Loading & URL Parameter Logic ---
    final url = URL(window.location.href);
    final eventSlugFromUrl = url.searchParams.get('event');

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

    // --- Event Listeners ---
    form.addEventListener(
        'submit',
        (Event e) {
          e.preventDefault();
          // Use the event from the URL if it exists, otherwise use the one from the dropdown selector.
          final finalEventSlug = eventSlugFromUrl ?? eventSelector.value;
          _handleFormSubmit(
              emailInput.value, finalEventSlug, status, submitButton);
        }.toJS);

    newClaimButton.addEventListener(
        'click',
        (Event e) {
          // A full page reload is the cleanest way to reset the state.
          window.location.href = '/';
        }.toJS);
  } catch (e) {
    window
        .alert('A fatal error occurred during initialization: ${e.toString()}');
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
          option.value = eventMap['slug'] ?? '';
          option.text = eventMap['name'] ?? '';
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
  }
}

Future<void> _handleFormSubmit(String email, String eventSlug,
    HTMLDivElement status, HTMLButtonElement submitButton) async {
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

    if (response.ok) {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final certificateUrl = data['certificate_url'] as String?;
      if (certificateUrl != null) {
        _showThankYouScreen(certificateUrl);
      } else {
        status.innerText =
            'Error: La respuesta del servidor no contenía una URL de certificado.';
      }
    } else {
      status.innerText =
          'Error: ${responseBody.isNotEmpty ? responseBody : response.statusText}';
    }
  } catch (e) {
    status.innerText = 'Error de conexión con el servidor.';
  } finally {
    submitButton.disabled = false;
  }
}

void _showThankYouScreen(String certificateUrl) {
  final claimView = querySelector('#claim-view') as HTMLDivElement;
  final thankYouView = querySelector('#thank-you-view') as HTMLDivElement;
  final mainTitle = querySelector('#main-title') as HTMLHeadingElement;

  claimView.style.display = 'none';
  thankYouView.style.display = 'block';
  mainTitle.innerText = '¡Insignia Generada!';

  final certificateLink =
      querySelector('#certificate-link') as HTMLAnchorElement;
  final openBadgeLink = querySelector('#openbadge-link') as HTMLAnchorElement;

  certificateLink.href = certificateUrl;
  openBadgeLink.href = certificateUrl.replaceAll('.html', '.json');
}

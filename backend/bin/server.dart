import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:github/github.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:gdg_alicante_badges_backend/certificate_generator.dart';

// Imports for official Google APIs
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis_auth/auth_io.dart';
import 'package:uuid/uuid.dart';

// --- Globals for APIs and Config ---

// Firestore API client
late firestore.FirestoreApi _api;
// Base path for Firestore documents
late String _dbRoot;

// GitHub configuration.
late String _githubOwner;
late String _githubPublicRepo;
late String _githubToken;
late GitHub _github;

// --- Helper Functions ---

// Converts the verbose Firestore Document object into a simple Dart Map.
Map<String, dynamic> _fromFirestoreValues(firestore.Document doc) {
  final fields = doc.fields ?? <String, firestore.Value>{};
  final map = <String, dynamic>{};
  for (var entry in fields.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value.stringValue != null) {
      map[key] = value.stringValue;
    } else if (value.booleanValue != null) {
      map[key] = value.booleanValue;
    } else if (value.integerValue != null) {
      map[key] = int.tryParse(value.integerValue!);
    } else if (value.doubleValue != null) {
      map[key] = value.doubleValue;
    } else if (value.nullValue != null) {
      map[key] = null;
    } else if (value.mapValue != null) {
      // Note: Not implemented for this script as it's not needed yet.
    }
  }
  return map;
}

// Converts a Dart Map into the verbose format required by the Google Firestore API.
Map<String, firestore.Value> _toFirestoreValues(Map<String, dynamic> data) {
  final values = <String, firestore.Value>{};
  for (var entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value is String) {
      values[key] = firestore.Value(stringValue: value);
    } else if (value is bool) {
      values[key] = firestore.Value(booleanValue: value);
    } else if (value is int) {
      values[key] = firestore.Value(integerValue: value.toString());
    } else if (value is double) {
      values[key] = firestore.Value(doubleValue: value);
    } else if (value == null) {
      values[key] = firestore.Value(nullValue: 'NULL_VALUE');
    }
  }
  return values;
}

String _hashEmailForFirestore(String email) {
  final bytes = utf8.encode(email);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

// --- Route Handlers ---

final _router = Router()
  ..get('/', _rootHandler)
  ..post('/claim', _claimHandler)
  ..get('/events', _eventsHandler);

Response _rootHandler(Request req) {
  return Response.ok('Welcome to the GDG Alicante Badge Generator backend!\n');
}

Future<Response> _eventsHandler(Request request) async {
  try {
    final result = await _api.projects.databases.documents.list(
      '$_dbRoot',
      'event_details',
    );
    final eventList = result.documents?.map((doc) {
          final map = _fromFirestoreValues(doc);
          return {
            'slug': doc.name?.split('/').last, // Extract slug from full path
            'name': map['name'],
          };
        }).toList() ??
        [];
    return Response.ok(jsonEncode(eventList),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('Error fetching events: $e');
    return Response.internalServerError(
        body: 'No se pudieron obtener los eventos.');
  }
}

Future<Response> _claimHandler(Request request) async {
  // 1. Read the request body (email, event_slug).
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final email = params['email'];
  final eventSlug = params['event_slug'];

  if (email == null || eventSlug == null) {
    return Response.badRequest(body: 'Falta el email o el slug del evento');
  }

  // 2. Validate against Firestore.
  print('Validating $email for event $eventSlug...');
  final hashedEmail = _hashEmailForFirestore(email);
  final attendeeDocPath = '$_dbRoot/events/$eventSlug/attendees/$hashedEmail';

  try {
    final attendeeDoc =
        await _api.projects.databases.documents.get(attendeeDocPath);
    final attendee = _fromFirestoreValues(attendeeDoc);

    if (attendee.isEmpty) {
      return Response.notFound(
          'No se encontró un asistente con ese email para este evento.');
    }

    final attendeeName = attendee['name'];

    if (attendee['claimed_certificate'] == true) {
      return Response(409,
          body:
              'Certificado ya reclamado. <a href="${attendee['certificate_url']}">Ver certificado</a>');
    }

    // Fetch event details
    final eventDetailsDoc = await _api.projects.databases.documents
        .get('$_dbRoot/event_details/$eventSlug');
    final eventDetails = _fromFirestoreValues(eventDetailsDoc);
    if (eventDetails.isEmpty) {
      return Response.notFound(
          'No se encontraron detalles del evento para $eventSlug.');
    }
    eventDetails['slug'] = eventSlug; // Add slug to eventDetails

    // 3. Generate badge data.
    final certificateId = Uuid().v4();

    final badgeData = {
      'attendeeName': attendeeName,
      'eventName': eventDetails['name'],
      'certificateId': certificateId,
      'issueDate': eventDetails['issuedOn'],
      'gdgCommunityLink': eventDetails['gdgCommunityLink'],
      'email': email, // Add email for Open Badge
    };

    // Generate Open Badge JSON
    final openBadgeJson = generateAssertionJson(
        badgeData, _githubOwner, _githubPublicRepo, eventDetails);
    final openBadgePath = 'badges/$eventSlug/$certificateId.json';

    // Construct the full URL to the assertion JSON for the redirect template
    final assertionUrl =
        'https://${_githubOwner.toLowerCase()}.github.io/${_githubPublicRepo.toLowerCase()}/$openBadgePath';

    // Generate HTML badge, passing the assertion URL to it.
    final htmlContent = generateHtmlBadge(assertionUrl);
    final htmlPath = 'badges/$eventSlug/$certificateId.html';

    // 4. Commit HTML and Open Badge JSON to GitHub Pages.
    print(
        'Committing badge HTML and Open Badge JSON for $certificateId to GitHub Pages...');

    await commitFileToGitHub(
      _github,
      _githubOwner,
      _githubPublicRepo, // Commit to the public repo
      'gh-pages', // On the gh-pages branch
      htmlPath,
      htmlContent,
      'feat: Generate HTML badge for $attendeeName',
    );
    await commitFileToGitHub(
      _github,
      _githubOwner,
      _githubPublicRepo, // Commit to the public repo
      'gh-pages', // On the gh-pages branch
      openBadgePath,
      openBadgeJson,
      'feat: Generate Open Badge JSON for $attendeeName',
    );

    // The URL will point to the public GitHub Pages URL.
    final certificateUrl =
        'https://${_githubOwner.toLowerCase()}.github.io/${_githubPublicRepo.toLowerCase()}/$htmlPath';

    // 5. Update Firestore.
    print('Updating Firestore record for $email...');
    final updateData = {
      'claimed_certificate': true,
      'certificate_url': certificateUrl
    };
    final updateDoc =
        firestore.Document(fields: _toFirestoreValues(updateData));
    await _api.projects.databases.documents.patch(updateDoc, attendeeDocPath,
        updateMask_fieldPaths: updateData.keys.toList());

    // 6. Return the certificate URL.
    return Response.ok(
      jsonEncode({
        'certificate_url': certificateUrl,
        'github_owner': _githubOwner,
        'github_repo': _githubPublicRepo
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } on firestore.DetailedApiRequestError catch (e) {
    if (e.status == 404) {
      return Response.notFound(
          'Attendee with that email not found for this event.');
    }
    print('Firestore API Error: ${e.message}');
    return Response.internalServerError(
        body: 'Ocurrió un error con la base de datos.');
  } catch (e) {
    print('Error during claim process: $e');
    return Response.internalServerError(body: 'Ocurrió un error interno.');
  }
}

// --- Main Execution ---

void main(List<String> args) async {
  // --- GCP Authentication ---
  final projectId = Platform.environment['GCP_PROJECT_ID'];
  if (projectId == null) {
    print('GCP_PROJECT_ID environment variable not set.');
    exit(1);
  }

  // This works locally (via gcloud auth) and on Cloud Run (via service account)
  final client = await clientViaApplicationDefaultCredentials(
    scopes: [firestore.FirestoreApi.datastoreScope],
  );
  _api = firestore.FirestoreApi(client);
  _dbRoot = 'projects/$projectId/databases/(default)/documents';

  // --- GitHub Configuration ---
  _githubOwner = Platform.environment['GITHUB_REPO_OWNER']!;
  _githubPublicRepo = Platform.environment['GITHUB_REPO_NAME']!;
  _githubToken = Platform.environment['GH_PAGES_DEPLOY_TOKEN']!;
  _github = GitHub(auth: Authentication.withToken(_githubToken));

  // --- Server Setup ---
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // Explicitly allow all origins for CORS
  final corsMiddleware = corsHeaders(headers: {
    'Access-Control-Allow-Origin': '*',
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware)
      .addHandler(_router);

  final server = await io.serve(handler, InternetAddress.anyIPv6, port);
  print('Server listening on port ${server.port}');
}

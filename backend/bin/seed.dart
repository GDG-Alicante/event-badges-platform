import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:github/github.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:args/args.dart';
import 'package:gdg_alicante_badges_backend/certificate_generator.dart';

// Imports for official Google APIs
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis_auth/auth_io.dart';

// --- Helper Functions ---

// Prompts the user for input with a default value.
String _prompt(String prompt, String defaultValue) {
  stdout.write('$prompt (default: $defaultValue): ');
  final input = stdin.readLineSync();
  var result = input == null || input.isEmpty ? defaultValue : input;
  if (result.startsWith('"') && result.endsWith('"')) {
    result = result.substring(1, result.length - 1);
  }
  if (result.startsWith("'") && result.endsWith("'")) {
    result = result.substring(1, result.length - 1);
  }
  return result;
}

// Hashes an email for use as a Firestore document ID.
String _hashEmailForFirestore(String email) {
  final bytes = utf8.encode(email);
  final digest = sha256.convert(bytes);
  return digest.toString();
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
    } else if (value is Map) {
      // Handle nested maps recursively, though not needed for this script yet.
      values[key] = firestore.Value(
          mapValue: firestore.MapValue(
              fields: _toFirestoreValues(value as Map<String, dynamic>)));
    }
    // Note: Does not handle lists/arrays yet.
  }
  return values;
}

// --- Main Execution ---

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('slug', help: 'Event slug')
    ..addOption('name', help: 'Event name')
    ..addOption('description', help: 'Event description')
    ..addOption('image', help: 'URL or local path to the badge image')
    ..addOption('gdgCommunityLink', help: 'Link to the event on GDG Community')
    ..addOption('issuedOn', help: 'Date of the event')
    ..addOption('evidence', help: 'Link to the evidence of the event')
    ..addOption('csvPath', help: 'Path to the CSV file with attendees')
    ..addOption('tags', help: 'Comma-separated list of tags')
    ..addOption('narrative', help: 'Narrative for the assertion');

  final argResults = parser.parse(args);

  // --- GCP Authentication using official googleapis library ---
  final projectId = Platform.environment['GCP_PROJECT_ID'];
  if (projectId == null) {
    print('GCP_PROJECT_ID environment variable not set.');
    exit(1);
  }
  print('Using GCP Project ID: $projectId');
  print('Authenticating with GCP via Application Default Credentials...');

  // Obtain an authenticated client that uses ADC (gcloud auth application-default login)
  final client = await clientViaApplicationDefaultCredentials(
    scopes: [firestore.FirestoreApi.datastoreScope],
  );
  // Create the Firestore API client
  final api = firestore.FirestoreApi(client);
  final dbRoot = 'projects/$projectId/databases/(default)/documents';
  
  print('Authentication successful.');

  // --- GitHub Configuration ---
  final githubOwner = Platform.environment['GITHUB_REPO_OWNER']!;
  final githubRepo = Platform.environment['GITHUB_REPO_NAME']!;
  final githubToken = Platform.environment['GH_PAGES_DEPLOY_TOKEN']!;
  final github = GitHub(auth: Authentication.withToken(githubToken));

  // --- Issuer Details ---
  final defaultIssuerDetails = {
    'name': 'GDG Alicante',
    'url': 'https://gdg.community.dev/gdg-alicante/',
    'image':
        'https://res.cloudinary.com/startup-grind/image/upload/c_limit,dpr_2,f_auto,g_center,h_1440,q_auto:good,w_2048/v1/gcs/platform-data-goog/chapter_photos/cabecera6.png',
    'email': 'gdg-alicante@gmail.com',
    'description': 'Comunidad oficial de Google Developers en Alicante.',
  };

  final issuerDetails = <String, dynamic>{};
  for (var entry in defaultIssuerDetails.entries) {
    final value = _prompt('Enter value for issuer ${entry.key}', entry.value);
    issuerDetails[entry.key] = value;
  }

  final issuerJson = generateIssuerJson(issuerDetails, githubOwner, githubRepo);
  await commitFileToGitHub(
    github,
    githubOwner,
    githubRepo,
    'gh-pages',
    'badges/issuer.json',
    issuerJson,
    'feat: Add issuer.json',
  );

  // --- Event Details ---
  final defaultEventDetails = {
    'name': 'DevFest Alicante 2025',
    'description':
        'Se certifica que el participante asistió al DevFest Alicante 2025, organizado por GDG Alicante, con charlas sobre IA, desarrollo web, bases de datos avanzadas y accesibilidad.',
    'image': 'https://example.com/badge.png',
    'gdgCommunityLink':
        'https://gdg.community.dev/events/details/google-gdg-alicante-presents-devfest-2025-alicante/',
    'issuedOn': '2025-09-18T16:00:00Z',
    'evidence': '[]',
    'tags': 'DevFest, IA, Desarrollo Web, Bases de Datos, Accesibilidad',
    'narrative': 'Participó en todas las charlas de la jornada.',
  };

  final eventSlug = argResults['slug'] ?? _prompt('Enter the event slug', 'test3');
  print('Seeding Firestore for event: $eventSlug');

  final eventDetails = <String, dynamic>{};
  eventDetails['slug'] = eventSlug;
  for (var entry in defaultEventDetails.entries) {
    final value = argResults[entry.key] ?? _prompt('Enter value for ${entry.key}', entry.value);
    eventDetails[entry.key] = value;
  }

  await commitFileToGitHub(
    github,
    githubOwner,
    githubRepo,
    'gh-pages',
    'badges/$eventSlug/.gitkeep',
    '',
    'feat: Create event directory for $eventSlug',
  );

  // Handle image
  final imagePath = eventDetails['image'] as String;
  if (imagePath.startsWith('http')) {
    try {
      final response = await http.get(Uri.parse(imagePath));
      if (response.statusCode == 200) {
        final image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          final pngBytes = img.encodePng(image);
          final imagePathInRepo = 'badges/$eventSlug/badge.png';
          await commitFileToGitHub(
            github,
            githubOwner,
            githubRepo,
            'gh-pages',
            imagePathInRepo,
            base64Encode(pngBytes),
            'feat: Add badge image for $eventSlug',
            isBase64: true,
          );
          eventDetails['image'] =
              'https://$githubOwner.github.io/$githubRepo/$imagePathInRepo';
        } else {
          print('Error: Could not decode image from $imagePath');
        }
      } else {
        print(
            'Error: Could not download image from $imagePath. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading or processing image: $e');
    }
  } else {
    final imageFile = File(imagePath);
    if (imageFile.existsSync()) {
      final imageContent = imageFile.readAsBytesSync();
      final imagePathInRepo = 'badges/$eventSlug/badge.png';
      await commitFileToGitHub(
        github,
        githubOwner,
        githubRepo,
        'gh-pages',
        imagePathInRepo,
        base64Encode(imageContent),
        'feat: Add badge image for $eventSlug',
        isBase64: true,
      );
      eventDetails['image'] =
          'https://$githubOwner.github.io/$githubRepo/$imagePathInRepo';
    } else {
      print('Error: Image file not found at $imagePath');
    }
  }

  // --- Firestore Write Operations using googleapis ---

  // Seed event details
  print('  - Writing event details for $eventSlug to Firestore...');
  final eventDetailsDoc = firestore.Document(fields: _toFirestoreValues(eventDetails));
  await api.projects.databases.documents.patch(
    eventDetailsDoc,
    '$dbRoot/event_details/$eventSlug',
  );
  print('  - Added event details for $eventSlug');

  // Generate and commit BadgeClass JSON
  final badgeClassJson = generateBadgeClassJson(eventDetails, githubOwner, githubRepo);
  final badgeClassPath = 'badges/$eventSlug/badge.json';
  await commitFileToGitHub(
    github,
    githubOwner,
    githubRepo,
    'gh-pages',
    badgeClassPath,
    badgeClassJson,
    'feat: Add BadgeClass JSON for $eventSlug',
  );

  final csvPath = argResults['csvPath'] ?? _prompt('Enter the path to the CSV file', 'data/test.csv');

  final input = File(csvPath).openRead();
  final fields = await input
      .transform(utf8.decoder)
      .transform(const CsvToListConverter(shouldParseNumbers: false, eol: '\n'))
      .toList();

  fields.removeAt(0); // Remove header row

  // Create the parent event document
  final eventDoc = firestore.Document(fields: _toFirestoreValues({'name': 'Event $eventSlug'}));
  await api.projects.databases.documents.patch(
    eventDoc,
    '$dbRoot/events/$eventSlug',
  );

  print('length: ${fields.length}');

  for (var field in fields) {
    final firstName = field[2];
    final lastName = field[3];
    final email = field[4];
    final name = '$firstName $lastName';
    print('name: $name');

    final hashedEmail = _hashEmailForFirestore(email);

    try {
      final attendeeData = {
        'name': name,
        'email': hashedEmail,
        'claimed_certificate': false,
        'certificate_url': null,
      };
      final attendeeDoc = firestore.Document(fields: _toFirestoreValues(attendeeData));
      // Use patch to create or update the document.
      await api.projects.databases.documents.patch(
        attendeeDoc,
        '$dbRoot/events/$eventSlug/attendees/$hashedEmail',
      );
      print('  - Added attendee $hashedEmail for event $eventSlug');
    } catch (e) {
      print('  - Error adding attendee $hashedEmail for event $eventSlug: $e');
    }
  }

  print('Seeding complete!');
  exit(0);
}

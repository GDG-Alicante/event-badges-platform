import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:github/github.dart';
import 'package:gdg_alicante_badges_backend/templates/badge_template.dart';

// #############################################################################
// # UUID and Hashing Utilities
// #############################################################################

class Uuid {
  final _random = Random();
  String v4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (match) {
        final r = (_random.nextInt(16));
        final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
        return v.toRadixString(16);
      },
    );
  }
}

String _hashEmail(String email) {
  final bytes = utf8.encode(email);
  final digest = sha256.convert(bytes);
  return 'sha256\$$digest';
}

// #############################################################################
// # HTML Badge Generation
// #############################################################################

String generateHtmlBadge(String attendeeName) {
  final templateContent = getBadgeHtmlTemplate();
  // Simple string replacement is enough, no need for a full template engine.
  return templateContent.replaceFirst('{{RECIPIENT_NAME}}', attendeeName);
}

// #############################################################################
// # Open Badge JSON Generation
// #############################################################################

String generateIssuerJson(
    Map<String, dynamic> issuerDetails, String githubOwner, String githubRepo) {
  return jsonEncode({
    '@context': 'https://w3id.org/openbadges/v2',
    'id':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/issuer.json',
    'type': 'Issuer',
    'name': issuerDetails['name'],
    'url': issuerDetails['url'],
    'image': issuerDetails['image'],
    'email': issuerDetails['email'],
    'description': issuerDetails['description'],
  });
}

String generateBadgeClassJson(
    Map<String, dynamic> eventDetails, String githubOwner, String githubRepo) {
  final eventSlug = eventDetails['slug'];
  final badgeClass = {
    '@context': 'https://w3id.org/openbadges/v2',
    'type': 'BadgeClass',
    'id':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/$eventSlug/badge.json',
    'name': eventDetails['name'],
    'description': eventDetails['description'],
    'image': eventDetails['image'], // This now comes from the seeder
    'criteria': eventDetails['gdgCommunityLink'],
    'issuer':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/issuer.json',
  };

  if (eventDetails['tags'] != null &&
      (eventDetails['tags'] as String).isNotEmpty) {
    badgeClass['tags'] = (eventDetails['tags'] as String)
        .split(',')
        .map((e) => e.trim())
        .toList();
  }

  return jsonEncode(badgeClass);
}

String generateAssertionJson(Map<String, dynamic> badgeData, String githubOwner,
    String githubRepo, Map<String, dynamic> eventDetails) {
  final eventSlug = eventDetails['slug'];
  final assertion = {
    '@context': 'https://w3id.org/openbadges/v2',
    'type': 'Assertion',
    'id':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/$eventSlug/${badgeData['certificateId']}.json',
    'recipient': {
      'type': 'email',
      'identity': _hashEmail(badgeData['email']),
      'hashed': true,
    },
    'badge':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/$eventSlug/badge.json',
    'verification': {
      'type': 'HostedBadge',
      'url':
          'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/$eventSlug/${badgeData['certificateId']}.json',
    },
    'issuedOn': eventDetails['issuedOn'],
    'issuer':
        'https://${githubOwner.toLowerCase()}.github.io/${githubRepo.toLowerCase()}/badges/issuer.json',
  };

  if (eventDetails['narrative'] != null &&
      (eventDetails['narrative'] as String).isNotEmpty) {
    assertion['narrative'] = eventDetails['narrative'];
  }

  if (eventDetails['evidence'] != null &&
      (eventDetails['evidence'] as String).isNotEmpty) {
    try {
      final evidence = jsonDecode(eventDetails['evidence']);
      assertion['evidence'] = evidence;
    } catch (e) {
      print('Error parsing evidence JSON: $e');
    }
  }

  return jsonEncode(assertion);
}

// #############################################################################
// # GitHub File Committing
// #############################################################################

Future<void> commitFileToGitHub(
  GitHub github,
  String owner,
  String repo,
  String branch,
  String path,
  String content,
  String message, {
  bool isBase64 = false,
}) async {
  final slug = RepositorySlug(owner, repo);
  print(
      'Attempting to commit to GitHub: $owner/$repo on branch $branch, path $path');

  try {
    // First, try to create the file
    final response = await github.repositories.createFile(
      slug,
      CreateFile(
        path: path,
        content: isBase64 ? content : base64Encode(utf8.encode(content)),
        message: message,
        branch: branch,
      ),
    );
    print(
        'Successfully created $path in GitHub. Commit SHA: ${response.commit?.sha}');
  } catch (e) {
    if (e is GitHubError &&
        (e.message?.toLowerCase().contains('sha') ?? false)) {
      // File already exists, update it
      print('File $path already exists, updating...');
      try {
        final contents =
            await github.repositories.getContents(slug, path, ref: branch);
        final sha = contents.file?.sha;
        if (sha != null) {
          final response = await github.repositories.updateFile(
              slug,
              path,
              message,
              isBase64 ? content : base64Encode(utf8.encode(content)),
              sha,
              branch: branch);
          print(
              'Successfully updated $path in GitHub. Commit SHA: ${response.commit?.sha}');
        }
      } catch (e, stacktrace) {
        print('Error updating file in GitHub: $e\nStacktrace: $stacktrace');
      }
    } else {
      print('Error committing file to GitHub: $e');
    }
  }
}

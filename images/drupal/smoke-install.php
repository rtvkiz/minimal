<?php
// Non-interactive Drupal install for test-dev.sh. It passes no database form,
// so the installer must take the database from the env-driven settings.php
// and complete with that file read-only — the deployment path this image ships.
chdir('/usr/share/drupal');
$loader = require 'autoload.php';
require_once 'core/includes/install.core.inc';
install_drupal($loader, [
  'interactive' => FALSE,
  'parameters' => ['profile' => 'minimal', 'langcode' => 'en'],
  'forms' => ['install_configure_form' => [
    'site_name' => 'smoketest', 'site_mail' => 'admin@example.com',
    'account' => ['name' => 'admin', 'mail' => 'admin@example.com', 'pass' => ['pass1' => 'smoketest', 'pass2' => 'smoketest']],
    'enable_update_status_module' => FALSE, 'enable_update_status_emails' => FALSE,
  ]],
]);
echo "INSTALLED ", \Drupal::VERSION, PHP_EOL;

<?php

declare(strict_types=1);

require_once __DIR__.'/editorial.php';

$assertions = 0;
$assertSame = static function (mixed $expected, mixed $actual, string $message) use (&$assertions): void {
    $assertions++;
    if ($expected !== $actual) {
        throw new RuntimeException($message.'; expected '.var_export($expected, true).' got '.var_export($actual, true));
    }
};
$assertTrue = static function (bool $actual, string $message) use (&$assertions): void {
    $assertions++;
    if (! $actual) {
        throw new RuntimeException($message);
    }
};
$assertThrows = static function (callable $operation, string $message) use (&$assertions): void {
    $assertions++;
    try {
        $operation();
    } catch (Throwable) {
        return;
    }
    throw new RuntimeException($message);
};

$now = new DateTimeImmutable('2026-11-26T12:00:00+00:00');
$fixture = c31_build_fixture($now, '0123456789abcdef');
$assertSame(2, $fixture['schemaVersion'], 'Envelope must be schema2');
$assertSame('restrictions', $fixture['datasetKey'], 'Dataset key must match the restrictions contract');
$assertSame('c31-qa-0123456789abcdef', $fixture['version'], 'Version must use a synthetic C31 identifier');
$assertSame('2026-11-26T12:00:00Z', $fixture['generatedAt'], 'Fixture timestamp must be UTC and reproducible');
$jurisdiction = $fixture['jurisdictions'][0];
$coverage = $jurisdiction['coverages'][0];
$rule = $coverage['rules'][0];
$assertSame('c31-synthetic-off', $jurisdiction['id'], 'Fixture must target only the C31 synthetic jurisdiction');
$assertSame('C31 Synthetic Jurisdiction OFF', $jurisdiction['name'], 'Fixture jurisdiction name must match the isolated editorial model');
$assertSame(['99999'], $jurisdiction['municipalityCodes'], 'Municipality code must remain a string');
$assertSame(false, $jurisdiction['consultationEnabled'], 'Jurisdiction must remain OFF');
$assertSame(false, $coverage['consultationEnabled'], 'Coverage must remain OFF');
$assertSame('partial', $coverage['coverageCompleteness'], 'Coverage must remain partial');
$assertSame('C31_SYNTHETIC_RESTRICTION_RULE', $rule['id'], 'Rule must be synthetic');
$assertSame([1, 2], $rule['digits'], 'Fixture must preserve the stated restriction digits');
$assertSame([], $rule['conditions'], 'Schema2 conditions must be a list');
$assertTrue(! array_key_exists('publish', $jurisdiction), 'Fixture must not use publish=false as an OFF substitute');
$assertTrue(str_starts_with($rule['sourceUrl'], 'https://example.test/'), 'Fixture source must be explicitly synthetic');

$createFields = c31_build_manual_fields($fixture, 17, '1,2', false);
$updateFields = c31_build_manual_fields($fixture, 17, '1,2,3', true);
$assertSame(17, $createFields['jurisdiction_id'], 'Create must select the exact synthetic jurisdiction');
$assertSame('0', $createFields['consultation_enabled'], 'Manual form must keep jurisdiction consultation OFF');
$assertSame('0', $createFields['coverages'][0]['consultation_enabled'], 'Manual coverage must remain OFF');
$assertTrue(! array_key_exists('coverage_completeness', $createFields['coverages'][0]), 'Manual form must not invent a control absent from Laravel; schema2 defaults new coverage to partial');
$assertSame('1,2', $createFields['coverages'][0]['rules'][0]['digits'], 'Create must use form field names and digit text');
$assertTrue(! array_key_exists('_method', $createFields), 'Create must use the authentic POST method');
$assertSame('PUT', $updateFields['_method'], 'Update must use the authentic form method override');
$assertSame('1,2,3', $updateFields['coverages'][0]['rules'][0]['digits'], 'Update must change only the synthetic digits');

$formHtml = '<form method="POST" action="/admin/restrictions/confirm"><input type="hidden" name="_token" value="csrf&amp;token"><input type="hidden" name="publication_revision" value="0"><select name="evidence_url"><option value="">Choose</option><option value="https://example.test/c31">Synthetic source</option></select></form>';
$form = c31_parse_html_form($formHtml, '/admin/restrictions/confirm');
$assertSame('csrf&token', $form['hidden']['_token'], 'Form parser must decode HTML entities in CSRF values');
$assertSame('0', $form['hidden']['publication_revision'], 'Form parser must preserve revision as rendered');
$assertSame([''], $form['selects']['evidence_url'], 'Form parser must model the browser default to the first option');
$assertSame(['', 'https://example.test/c31'], $form['options']['evidence_url'], 'Form parser must collect rendered evidence choices');

$editHtml = '<form method="POST" action="/admin/restrictions/17"><input type="hidden" name="_token" value="t"><input type="hidden" name="_method" value="PUT"><select name="coverages[0][pair]"><option value="car|private" selected>Car</option></select><textarea name="coverages[0][source_urls]">https://example.test/c31</textarea><input name="coverages[0][rules][0][digits]" value="1,2"><input type="checkbox" name="coverages[0][rules][0][applies_on_holidays]" value="1"></form>';
$editForm = c31_parse_html_form($editHtml, '/admin/restrictions/17');
$assertSame('PUT', $editForm['submission']['_method'], 'Update request must use the rendered method override');
$assertSame('car|private', $editForm['submission']['coverages[0][pair]'], 'Update must retain the selected form pair');
$assertSame('https://example.test/c31', $editForm['submission']['coverages[0][source_urls]'], 'Update must retain the rendered textarea');
$assertSame('1,2', $editForm['submission']['coverages[0][rules][0][digits]'], 'Update must start from the actual rendered digit value');
$assertTrue(! array_key_exists('coverages[0][rules][0][applies_on_holidays]', $editForm['submission']), 'Unchecked form checkbox must not be submitted');
$formEncoded = http_build_query($editForm['submission'], '', '&', PHP_QUERY_RFC3986);
parse_str($formEncoded, $parsedSubmission);
$assertSame('1,2', $parsedSubmission['coverages'][0]['rules'][0]['digits'], 'Flat form names must round-trip as Laravel nested request fields');

$reviewHtml = '<form method="POST" action="/admin/restrictions/imports/4/confirm"><input name="_token" value="t"><table><tr><td><input type="checkbox" name="rows[]" value="41"></td><td>valid · publicable como borrador</td></tr><tr><td><input type="checkbox" name="rows[]" value="42"></td><td>invalid · no publicable</td></tr></table></form>';
$assertSame('41', c31_select_publishable_row_id($reviewHtml), 'Selection must include only the valid, publishable row');

$origin = 'http://127.0.0.1:8878';
$assertSame('/admin/restrictions/history', c31_local_redirect_path($origin, '/admin/restrictions/history'), 'Relative redirect must remain local');
$assertSame('/admin/restrictions/history', c31_local_redirect_path($origin, $origin.'/admin/restrictions/history'), 'Absolute same-origin redirect must remain local');
$assertThrows(static fn () => c31_local_redirect_path($origin, 'https://example.test/steal'), 'External redirect must be rejected');
$assertThrows(static fn () => c31_local_redirect_path($origin, '//example.test/steal'), 'Protocol-relative redirect must be rejected');

fwrite(STDOUT, 'C31_PURE_HELPERS_PASS assertions='.$assertions.PHP_EOL);

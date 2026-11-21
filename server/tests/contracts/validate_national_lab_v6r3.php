<?php

declare(strict_types=1);

use App\Services\RestrictionContractValidator;

$server = dirname(__DIR__, 2);
require_once $server.'/app/Services/RestrictionContractValidator.php';
$lab = $server.'/database/data/restrictions/lab';
$manifestPath = $lab.'/national_sources_manifest_v1.json';
$manifest = json_decode((string) file_get_contents($manifestPath), true, 512, JSON_THROW_ON_ERROR);
$validator = new RestrictionContractValidator;

function requireValue(bool $condition, string $message): void
{
    if (! $condition) {
        throw new RuntimeException($message);
    }
}

function expectRejected(string $label, callable $operation): void
{
    try {
        $operation();
    } catch (DomainException $exception) {
        echo "PASS NEGATIVE {$label}: {$exception->getMessage()}\n";
        return;
    }
    throw new RuntimeException("Negative case unexpectedly passed: {$label}");
}

function labFile(string $lab, mixed $relative, string $label): string
{
    if (! is_string($relative) || $relative === '') {
        throw new DomainException("{$label} must be a relative LAB path.");
    }
    $normalized = str_replace('\\', '/', $relative);
    $parts = explode('/', $normalized);
    if (str_starts_with($normalized, '/') ||
        preg_match('/^[A-Za-z]:/', $normalized) === 1 ||
        in_array('', $parts, true) ||
        in_array('.', $parts, true) ||
        in_array('..', $parts, true)) {
        throw new DomainException("{$label} cannot traverse outside LAB.");
    }
    $labPath = realpath($lab);
    $filePath = realpath($lab.DIRECTORY_SEPARATOR.implode(DIRECTORY_SEPARATOR, $parts));
    if ($labPath === false || $filePath === false ||
        ! str_starts_with($filePath, $labPath.DIRECTORY_SEPARATOR)) {
        throw new DomainException("{$label} is missing or escapes LAB.");
    }
    return $filePath;
}

function assertUniqueEnabledCodes(array $rows): array
{
    $owners = [];
    foreach ($rows as $row) {
        if (($row['consultationEnabled'] ?? false) !== true) {
            continue;
        }
        foreach ($row['municipalityCodes'] ?? [] as $code) {
            if (isset($owners[$code])) {
                throw new DomainException("Enabled DIVIPOLA collision {$code}: {$owners[$code]} / {$row['id']}");
            }
            $owners[$code] = $row['id'];
        }
    }
    return $owners;
}

function assertPartialScopes(array $rows): void
{
    foreach ($rows as $row) {
        foreach ($row['coverages'] as $coverage) {
            if (($coverage['coverageCompleteness'] ?? null) !== 'partial') {
                continue;
            }
            foreach ($coverage['rules'] as $rule) {
                $hasScope = false;
                foreach ($rule['conditions'] ?? [] as $condition) {
                    if (($condition['type'] ?? null) === 'inside_scope_ref') {
                        $hasScope = true;
                    }
                }
                if (! $hasScope) {
                    throw new DomainException("Partial rule lacks spatial scope: {$rule['id']}");
                }
            }
        }
    }
}

function assertRuleDatesHaveZone(array $rows): void
{
    $pattern = '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/';
    foreach ($rows as $row) {
        foreach ($row['coverages'] as $coverage) {
            foreach ($coverage['rules'] as $rule) {
                foreach (['validFrom', 'verifiedAt'] as $key) {
                    if (! preg_match($pattern, (string) ($rule[$key] ?? ''))) {
                        throw new DomainException("{$key} needs explicit timezone: {$rule['id']}");
                    }
                }
                if (isset($rule['validUntil']) && ! preg_match($pattern, (string) $rule['validUntil'])) {
                    throw new DomainException("validUntil needs explicit timezone: {$rule['id']}");
                }
            }
        }
    }
}

requireValue(is_array($manifest) && ($manifest['schemaVersion'] ?? null) === 1, 'Unsupported source manifest schemaVersion');
requireValue(isset($manifest['release']) && is_array($manifest['release']), 'Manifest release is missing');
requireValue(isset($manifest['sources']) && is_array($manifest['sources']) && array_is_list($manifest['sources']), 'Manifest sources must be an ordered list');
$release = $manifest['release'];
foreach (['version', 'generatedAt', 'outputFile', 'shaFile'] as $key) {
    requireValue(is_string($release[$key] ?? null) && $release[$key] !== '', "Manifest release {$key} is required");
}
$generatedAt = new DateTimeImmutable($release['generatedAt']);
$expectedIds = [];
$sourceIds = [];
$sourceFiles = [];
$coverageCount = 0;
$ruleCount = 0;
$latestVerifiedAt = null;
$inputHashes = [];

foreach ($manifest['sources'] as $entry) {
    requireValue(is_array($entry), 'Every source manifest entry must be an object');
    foreach (['jurisdictionId', 'file', 'enabled', 'expectedSha256', 'provenance', 'editorialDate'] as $key) {
        requireValue(array_key_exists($key, $entry), "Source entry is missing {$key}");
    }
    requireValue(is_string($entry['jurisdictionId']) && $entry['jurisdictionId'] !== '', 'Source jurisdictionId is required');
    requireValue(is_bool($entry['enabled']), "Source enabled must be boolean: {$entry['jurisdictionId']}");
    requireValue(is_string($entry['expectedSha256']) && preg_match('/^[a-fA-F0-9]{64}$/', $entry['expectedSha256']) === 1, "Source expectedSha256 is invalid: {$entry['jurisdictionId']}");
    requireValue(is_string($entry['provenance']) && trim($entry['provenance']) !== '', "Source provenance is required: {$entry['jurisdictionId']}");
    requireValue(is_string($entry['editorialDate']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $entry['editorialDate']) === 1, "Source editorialDate is invalid: {$entry['jurisdictionId']}");

    $sourceId = $entry['jurisdictionId'];
    $sourceIds[] = $sourceId;
    requireValue(! in_array($entry['file'], $sourceFiles, true), "Duplicate source file: {$entry['file']}");
    $sourceFiles[] = $entry['file'];
    $sourcePath = labFile($lab, $entry['file'], 'source.file');
    $actualHash = hash_file('sha256', $sourcePath);
    requireValue(is_string($actualHash) && hash_equals(strtolower($entry['expectedSha256']), strtolower($actualHash)), "Source SHA-256 mismatch: {$entry['file']}");
    $inputHashes[$entry['file']] = $actualHash;
    $sourcePayload = json_decode((string) file_get_contents($sourcePath), true, 512, JSON_THROW_ON_ERROR);
    if (array_key_exists('jurisdictions', $sourcePayload)) {
        requireValue(($sourcePayload['schemaVersion'] ?? null) === 2 && ($sourcePayload['datasetKey'] ?? null) === 'restrictions', "Invalid preserved source envelope: {$entry['file']}");
        requireValue(count($sourcePayload['jurisdictions']) === 1 && is_array($sourcePayload['jurisdictions'][0]), "Expected one source jurisdiction: {$entry['file']}");
        $jurisdiction = $sourcePayload['jurisdictions'][0];
    } else {
        $jurisdiction = $sourcePayload;
    }
    requireValue(($jurisdiction['id'] ?? null) === $sourceId, "Manifest jurisdictionId does not match source JSON: {$sourceId}");
    $validator->validateJurisdictionForEnvelope($jurisdiction, $sourceId, 2);
    $coverageVerifiedAt = [];
    foreach ($jurisdiction['coverages'] as $coverage) {
        $verified = new DateTimeImmutable($coverage['verifiedAt']);
        $coverageVerifiedAt[] = $verified;
        if ($entry['enabled']) {
            $latestVerifiedAt = $latestVerifiedAt === null || $verified > $latestVerifiedAt ? $verified : $latestVerifiedAt;
        }
    }
    if (! $entry['enabled']) {
        continue;
    }
    requireValue(($jurisdiction['consultationEnabled'] ?? null) === true, "Enabled source must have consultationEnabled=true: {$sourceId}");
    $expectedIds[] = $sourceId;
    $coverageCount += count($jurisdiction['coverages']);
    foreach ($jurisdiction['coverages'] as $coverage) {
        $ruleCount += count($coverage['rules']);
    }
}

requireValue($sourceIds === array_values(array_unique($sourceIds)), 'Duplicate source jurisdictionId in manifest');
$sortedSourceIds = $sourceIds;
sort($sortedSourceIds, SORT_STRING);
requireValue($sourceIds === $sortedSourceIds, 'Manifest sources must be ordered by jurisdictionId');
requireValue($latestVerifiedAt === null || $generatedAt >= $latestVerifiedAt, 'release.generatedAt precedes enabled source verifiedAt');

$snapshotPath = labFile($lab, $release['outputFile'], 'release.outputFile');
$sidecarPath = labFile($lab, $release['shaFile'], 'release.shaFile');
$snapshotSha = hash_file('sha256', $snapshotPath);
$sidecar = trim((string) file_get_contents($sidecarPath));
requireValue($sidecar === $snapshotSha.'  '.basename($snapshotPath), 'Snapshot SHA sidecar mismatch');
$snapshot = json_decode((string) file_get_contents($snapshotPath), true, 512, JSON_THROW_ON_ERROR);
requireValue(($snapshot['schemaVersion'] ?? null) === 2 && ($snapshot['datasetKey'] ?? null) === 'restrictions', 'Invalid combined schema2 envelope');
requireValue(($snapshot['version'] ?? null) === $release['version'], 'Snapshot version differs from manifest');
requireValue(($snapshot['generatedAt'] ?? null) === $release['generatedAt'], 'Snapshot generatedAt differs from manifest');
requireValue(isset($snapshot['jurisdictions']) && is_array($snapshot['jurisdictions']), 'Snapshot jurisdictions are missing');

$snapshotIds = [];
foreach ($snapshot['jurisdictions'] as $jurisdiction) {
    requireValue(is_array($jurisdiction), 'Snapshot jurisdiction must be an object');
    $validator->validateJurisdictionForEnvelope($jurisdiction, (string) ($jurisdiction['id'] ?? ''), 2);
    $snapshotIds[] = $jurisdiction['id'];
}
sort($expectedIds, SORT_STRING);
sort($snapshotIds, SORT_STRING);
requireValue($snapshotIds === $expectedIds, 'Snapshot IDs do not match enabled manifest sources');
requireValue(count($snapshot['jurisdictions']) === count($expectedIds), 'Snapshot jurisdiction count differs from manifest');
$owners = assertUniqueEnabledCodes($snapshot['jurisdictions']);
assertPartialScopes($snapshot['jurisdictions']);
assertRuleDatesHaveZone($snapshot['jurisdictions']);
requireValue(($owners['66170'] ?? null) === 'co-ris-dosquebradas', 'DIVIPOLA 66170 does not resolve to Dosquebradas');
requireValue(($owners['66001'] ?? null) === 'co-ris-pereira', 'DIVIPOLA 66001 does not resolve to Pereira');

$snapshotCoverageCount = 0;
$snapshotRuleCount = 0;
foreach ($snapshot['jurisdictions'] as $jurisdiction) {
    $snapshotCoverageCount += count($jurisdiction['coverages']);
    foreach ($jurisdiction['coverages'] as $coverage) {
        $snapshotRuleCount += count($coverage['rules']);
    }
}
requireValue($snapshotCoverageCount === $coverageCount, 'Snapshot coverage count differs from enabled sources');
requireValue($snapshotRuleCount === $ruleCount, 'Snapshot rule count differs from enabled sources');

$first = $snapshot['jurisdictions'][0];
$extraKey = $first;
$extraKey['unsupported'] = true;
expectRejected('unknown_key', fn () => $validator->validateJurisdictionForEnvelope($extraKey, $extraKey['id'], 2));

$duplicateRule = $first;
$targetCoverage = null;
foreach ($duplicateRule['coverages'] as $index => $coverage) {
    if (count($coverage['rules']) > 1) {
        $targetCoverage = $index;
        break;
    }
}
requireValue($targetCoverage !== null, 'No multi-rule coverage available for negative duplicate rule test');
$duplicateRule['coverages'][$targetCoverage]['rules'][1]['id'] = $duplicateRule['coverages'][$targetCoverage]['rules'][0]['id'];
expectRejected('duplicate_rule_id', fn () => $validator->validateJurisdictionForEnvelope($duplicateRule, $duplicateRule['id'], 2));

$duplicateCode = $snapshot['jurisdictions'];
$duplicateCode[1]['municipalityCodes'] = $duplicateCode[0]['municipalityCodes'];
expectRejected('duplicate_enabled_DIVIPOLA', fn () => assertUniqueEnabledCodes($duplicateCode));

$missingScope = $snapshot['jurisdictions'];
$missingScope[0]['coverages'][0]['rules'][0]['conditions'] = [];
expectRejected('missing_spatial_scope', fn () => assertPartialScopes($missingScope));

$timezoneMissing = $snapshot['jurisdictions'];
$timezoneMissing[0]['coverages'][0]['rules'][0]['validFrom'] = substr($timezoneMissing[0]['coverages'][0]['rules'][0]['validFrom'], 0, 19);
expectRejected('rule_date_without_timezone', fn () => assertRuleDatesHaveZone($timezoneMissing));

echo 'PASS PHP_SCHEMA2_REGISTRY jurisdictions='.count($snapshot['jurisdictions'])
    .' codes='.count($owners).' coverages='.$coverageCount.' rules='.$ruleCount
    .' manifest_sha256='.hash_file('sha256', $manifestPath)
    .' snapshot_sha256='.$snapshotSha."\n";
foreach ($inputHashes as $name => $hash) {
    echo "INPUT_SHA256 {$name} {$hash}\n";
}

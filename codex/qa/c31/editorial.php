<?php

declare(strict_types=1);

final class C31EditorialFailure extends RuntimeException
{
    public function __construct(public readonly string $stage, public readonly string $reason)
    {
        parent::__construct($reason);
    }
}

function c31_fail(string $stage, string $reason): never
{
    throw new C31EditorialFailure($stage, $reason);
}

function c31_log(string $name, string|int|bool $value): void
{
    fwrite(STDOUT, $name.'='.str_replace(["\r", "\n", " "], ['_', '_', '_'], (string) $value).PHP_EOL);
}

function c31_build_fixture(DateTimeImmutable $now, string $fixtureId): array
{
    if (preg_match('/^[a-f0-9]{16}$/D', $fixtureId) !== 1) {
        throw new InvalidArgumentException('Fixture id must be 16 lowercase hexadecimal characters.');
    }
    $utc = $now->setTimezone(new DateTimeZone('UTC'));
    $verifiedAt = $utc->modify('-1 day');
    $source = 'https://example.test/c31-synthetic-restrictions';

    return [
        'schemaVersion' => 2,
        'datasetKey' => 'restrictions',
        'version' => 'c31-qa-'.$fixtureId,
        'generatedAt' => $utc->format('Y-m-d\TH:i:s\Z'),
        'jurisdictions' => [[
            'schemaVersion' => 2,
            'id' => 'c31-synthetic-off',
            'name' => 'C31 Synthetic Jurisdiction OFF',
            'municipalityCodes' => ['99999'],
            'consultationEnabled' => false,
            'coverages' => [[
                'vehicleKind' => 'car',
                'serviceType' => 'private',
                'coverageCompleteness' => 'partial',
                'consultationEnabled' => false,
                'verifiedAt' => $verifiedAt->format('Y-m-d\TH:i:s\Z'),
                'staleAfter' => $utc->modify('+30 days')->format('Y-m-d\TH:i:s\Z'),
                'sourceUrls' => [$source],
                'rules' => [[
                    'id' => 'C31_SYNTHETIC_RESTRICTION_RULE',
                    'priority' => 100,
                    'effect' => 'restrict',
                    'validFrom' => $utc->modify('-1 day')->format('Y-m-d\TH:i:s\Z'),
                    'validUntil' => $utc->modify('+60 days')->format('Y-m-d\TH:i:s\Z'),
                    'weekdays' => [1],
                    'digitPosition' => 'lastNumeric',
                    'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 300, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false,
                    'sourceUrl' => $source,
                    'verifiedAt' => $verifiedAt->format('Y-m-d\TH:i:s\Z'),
                    'conditions' => [],
                ]],
            ]],
        ]],
    ];
}

function c31_fixture_bytes(array $fixture): string
{
    return json_encode($fixture, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)."\n";
}

function c31_datetime_local(string $isoDate): string
{
    return (new DateTimeImmutable($isoDate))->setTimezone(new DateTimeZone('America/Bogota'))->format('Y-m-d\TH:i');
}

function c31_build_manual_fields(array $fixture, int $jurisdictionId, string $digits, bool $update): array
{
    if ($jurisdictionId < 1 || preg_match('/^[0-9](?:,[0-9])*$/D', $digits) !== 1) {
        throw new InvalidArgumentException('Manual draft parameters are invalid.');
    }
    $jurisdiction = $fixture['jurisdictions'][0] ?? null;
    $coverage = $jurisdiction['coverages'][0] ?? null;
    $rule = $coverage['rules'][0] ?? null;
    if (! is_array($jurisdiction) || ! is_array($coverage) || ! is_array($rule)) {
        throw new InvalidArgumentException('Fixture is missing the manual form data.');
    }

    $fields = [
        'consultation_enabled' => '0',
        'coverages' => [[
            'pair' => $coverage['vehicleKind'].'|'.$coverage['serviceType'],
            'verified_at' => c31_datetime_local($coverage['verifiedAt']),
            'stale_after' => c31_datetime_local($coverage['staleAfter']),
            'consultation_enabled_present' => '1',
            'consultation_enabled' => '0',
            'source_urls' => implode("\n", $coverage['sourceUrls']),
            'rules' => [[
                'id' => $rule['id'],
                'priority' => (string) $rule['priority'],
                'effect' => $rule['effect'],
                'valid_from' => c31_datetime_local($rule['validFrom']),
                'valid_until' => c31_datetime_local($rule['validUntil']),
                'weekdays' => implode(',', $rule['weekdays']),
                'date_parity' => '',
                'digit_position' => $rule['digitPosition'],
                'digits' => $digits,
                'time_windows' => "05:00-20:00",
                'source_url' => $rule['sourceUrl'],
                'verified_at' => c31_datetime_local($rule['verifiedAt']),
                'conditions_json' => '[]',
            ]],
        ]],
    ];
    if (! $update) {
        $fields['jurisdiction_id'] = $jurisdictionId;
    } else {
        $fields['_method'] = 'PUT';
    }

    return $fields;
}

/** @return array{action:string,method:string,hidden:array<string,string>,values:array<string,list<string>>,selects:array<string,list<string>>,options:array<string,list<string>>,submission:array<string,mixed>,names:list<string>} */
function c31_parse_html_form(string $html, string $expectedAction): array
{
    if (! class_exists(DOMDocument::class)) {
        throw new RuntimeException('PHP DOM extension is required.');
    }
    $document = new DOMDocument;
    $previous = libxml_use_internal_errors(true);
    $loaded = $document->loadHTML($html, LIBXML_NONET | LIBXML_NOERROR | LIBXML_NOWARNING);
    libxml_clear_errors();
    libxml_use_internal_errors($previous);
    if (! $loaded) {
        throw new RuntimeException('Could not parse the rendered form.');
    }

    foreach ($document->getElementsByTagName('form') as $form) {
        $action = trim($form->getAttribute('action'));
        $actionPath = parse_url($action, PHP_URL_PATH) ?: '/';
        if ($actionPath !== $expectedAction || strtoupper($form->getAttribute('method') ?: 'GET') !== 'POST') {
            continue;
        }
        $hidden = [];
        $values = [];
        $selects = [];
        $options = [];
        $submission = [];
        $names = [];
        foreach ($form->getElementsByTagName('*') as $control) {
            $name = trim($control->getAttribute('name'));
            if ($name === '' || $control->hasAttribute('disabled')) {
                continue;
            }
            $names[] = $name;
            $tag = strtolower($control->tagName);
            if ($tag === 'input') {
                $type = strtolower($control->getAttribute('type'));
                $value = $control->getAttribute('value');
                if ($type === 'hidden') {
                    if (isset($hidden[$name]) && $hidden[$name] !== $value) {
                        throw new RuntimeException('Rendered form contains ambiguous hidden fields.');
                    }
                    $hidden[$name] = $value;
                }
                if ($type !== 'checkbox' || $control->hasAttribute('checked')) {
                    $values[$name][] = $value;
                    if (! in_array($type, ['submit', 'button', 'reset', 'file', 'image'], true)) {
                        c31_add_form_submission_value($submission, $name, $value);
                    }
                }
            } elseif ($tag === 'select') {
                $firstOption = null;
                foreach ($control->getElementsByTagName('option') as $option) {
                    $optionValue = $option->getAttribute('value');
                    $options[$name][] = $optionValue;
                    $firstOption ??= $optionValue;
                    if ($option->hasAttribute('selected')) {
                        $selects[$name][] = $option->getAttribute('value');
                    }
                }
                if (($selects[$name] ?? []) === [] && $firstOption !== null) {
                    $selects[$name][] = $firstOption;
                }
                foreach ($selects[$name] ?? [] as $selectedValue) {
                    c31_add_form_submission_value($submission, $name, $selectedValue);
                }
            } elseif ($tag === 'textarea') {
                $value = $control->textContent;
                $values[$name][] = $value;
                c31_add_form_submission_value($submission, $name, $value);
            }
        }
        foreach ($selects as $name => $selected) {
            $values[$name] = $selected;
        }

        return [
            'action' => $actionPath,
            'method' => 'POST',
            'hidden' => $hidden,
            'values' => $values,
            'selects' => $selects,
            'options' => $options,
            'submission' => $submission,
            'names' => array_values(array_unique($names)),
        ];
    }

    throw new RuntimeException('The expected authentic POST form was not rendered.');
}

function c31_add_form_submission_value(array &$submission, string $name, string $value): void
{
    if (str_ends_with($name, '[]')) {
        $submission[$name][] = $value;

        return;
    }
    if (array_key_exists($name, $submission) && $submission[$name] !== $value) {
        throw new RuntimeException('Rendered form contains duplicate scalar controls.');
    }
    $submission[$name] = $value;
}

function c31_select_publishable_row_id(string $html): string
{
    $document = new DOMDocument;
    $previous = libxml_use_internal_errors(true);
    $loaded = $document->loadHTML($html, LIBXML_NONET | LIBXML_NOERROR | LIBXML_NOWARNING);
    libxml_clear_errors();
    libxml_use_internal_errors($previous);
    if (! $loaded) {
        throw new RuntimeException('Could not parse the import review page.');
    }
    $xpath = new DOMXPath($document);
    $matches = [];
    foreach ($xpath->query('//form[@method="POST"]//input[@type="checkbox" and @name="rows[]"]') ?: [] as $input) {
        $row = $input->parentNode;
        while ($row !== null && strtolower($row->nodeName) !== 'tr') {
            $row = $row->parentNode;
        }
        $text = strtolower(preg_replace('/\s+/u', ' ', $row?->textContent ?? '') ?? '');
        if (str_contains($text, 'valid') && str_contains($text, 'publicable como borrador') && ! str_contains($text, 'invalid')) {
            $id = trim($input->getAttribute('value'));
            if (preg_match('/^[1-9][0-9]*$/D', $id) !== 1) {
                throw new RuntimeException('The valid import row has an invalid identifier.');
            }
            $matches[] = $id;
        }
    }
    if (count($matches) !== 1) {
        throw new RuntimeException('Import review must expose exactly one valid, publishable row.');
    }

    return $matches[0];
}

function c31_local_redirect_path(string $origin, string $location): string
{
    if ($location === '' || str_starts_with($location, '//')) {
        throw new RuntimeException('Redirect destination is empty or protocol-relative.');
    }
    $originParts = parse_url($origin);
    $locationParts = parse_url($location);
    if (! is_array($originParts) || ! is_array($locationParts)) {
        throw new RuntimeException('Redirect URI is malformed.');
    }
    if (isset($locationParts['scheme']) || isset($locationParts['host'])) {
        if (strtolower((string) ($locationParts['scheme'] ?? '')) !== 'http'
            || strtolower((string) ($locationParts['host'] ?? '')) !== strtolower((string) ($originParts['host'] ?? ''))
            || (int) ($locationParts['port'] ?? 80) !== (int) ($originParts['port'] ?? 80)
            || isset($locationParts['user']) || isset($locationParts['pass'])) {
            throw new RuntimeException('Redirect leaves the isolated loopback origin.');
        }
    }
    $path = (string) ($locationParts['path'] ?? '/');
    if ($path === '' || $path[0] !== '/' || str_contains($path, "\\") || preg_match('/%(?:2f|5c|2e)/i', $path) === 1) {
        throw new RuntimeException('Redirect path is not an allowed absolute local path.');
    }
    foreach (explode('/', $path) as $segment) {
        if ($segment === '.' || $segment === '..') {
            throw new RuntimeException('Redirect path traversal is not allowed.');
        }
    }

    return $path.(isset($locationParts['query']) ? '?'.$locationParts['query'] : '');
}

function c31_is_under(string $path, string $root): bool
{
    $path = rtrim(str_replace('\\', '/', strtolower($path)), '/');
    $root = rtrim(str_replace('\\', '/', strtolower($root)), '/');

    return $path === $root || str_starts_with($path, $root.'/');
}

function c31_require_form_names(array $form, array $required): void
{
    foreach ($required as $name) {
        if (! in_array($name, $form['names'], true)) {
            throw new RuntimeException('The authentic form is missing an expected field.');
        }
    }
}

final class C31HttpClient
{
    private $curl;

    public function __construct(private readonly string $origin, private readonly string $actorLabel)
    {
        if (! function_exists('curl_init')) {
            throw new RuntimeException('PHP cURL extension is required.');
        }
        $this->curl = curl_init();
        if ($this->curl === false) {
            throw new RuntimeException('Could not initialize the local HTTP client.');
        }
        curl_setopt($this->curl, CURLOPT_COOKIEFILE, '');
    }

    public function close(): void
    {
        if ($this->curl !== false) {
            $this->curl = false;
        }
    }

    /** @return array{status:int,headers:array<string,string>,body:string} */
    public function request(string $method, string $path, array|string|null $body = null, ?string $referer = null, bool $multipart = false): array
    {
        $method = strtoupper($method);
        $this->assertAllowed($method, $path, $body, $multipart);
        $headers = [];
        $responseHeaders = [];
        $responseBody = '';
        $tooLarge = false;
        $requestHeaders = ['Accept: text/html,application/json;q=0.9,*/*;q=0.5', 'Accept-Encoding: identity'];
        if ($referer !== null) {
            $refererPath = c31_local_redirect_path($this->origin, $referer);
            $requestHeaders[] = 'Referer: '.$this->origin.$refererPath;
        }

        $options = [
            CURLOPT_URL => $this->origin.$path,
            CURLOPT_RETURNTRANSFER => false,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0,
            CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_PROXY => '',
            CURLOPT_NOPROXY => '*',
            CURLOPT_PROTOCOLS => CURLPROTO_HTTP,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $requestHeaders,
            CURLOPT_HEADERFUNCTION => static function ($curl, string $line) use (&$responseHeaders): int {
                $length = strlen($line);
                if (preg_match('/^HTTP\/\S+\s+\d+/i', trim($line)) === 1) {
                    $responseHeaders = [];
                } elseif (str_contains($line, ':')) {
                    [$name, $value] = explode(':', $line, 2);
                    $responseHeaders[strtolower(trim($name))] = trim($value);
                }

                return $length;
            },
            CURLOPT_WRITEFUNCTION => static function ($curl, string $chunk) use (&$responseBody, &$tooLarge): int {
                if (strlen($responseBody) + strlen($chunk) > 5 * 1024 * 1024) {
                    $tooLarge = true;

                    return 0;
                }
                $responseBody .= $chunk;

                return strlen($chunk);
            },
        ];
        if ($method === 'GET') {
            $options[CURLOPT_HTTPGET] = true;
            $options[CURLOPT_POSTFIELDS] = null;
        } elseif ($multipart) {
            $options[CURLOPT_POST] = true;
            $options[CURLOPT_POSTFIELDS] = $body;
        } else {
            $options[CURLOPT_POST] = true;
            $options[CURLOPT_POSTFIELDS] = is_array($body) ? http_build_query($body, '', '&', PHP_QUERY_RFC3986) : (string) $body;
            $requestHeaders[] = 'Content-Type: application/x-www-form-urlencoded';
            $options[CURLOPT_HTTPHEADER] = $requestHeaders;
        }
        curl_setopt_array($this->curl, $options);
        $ok = curl_exec($this->curl);
        $status = (int) curl_getinfo($this->curl, CURLINFO_RESPONSE_CODE);
        if ($ok === false || $tooLarge) {
            throw new RuntimeException($tooLarge ? 'Local response exceeded the 5 MiB limit.' : 'Loopback HTTP request failed.');
        }
        $eventPath = parse_url($path, PHP_URL_PATH) ?: '/';
        c31_log('HTTP_'.$this->actorLabel, $method.' '.$eventPath.' status='.$status.' bytes='.strlen($responseBody).' sha256='.hash('sha256', $responseBody));

        return ['status' => $status, 'headers' => $responseHeaders, 'body' => $responseBody];
    }

    private function assertAllowed(string $method, string $path, array|string|null $body, bool $multipart): void
    {
        if (! str_starts_with($path, '/') || str_starts_with($path, '//') || str_contains($path, '#') || str_contains($path, "\\")
            || preg_match('/%(?:2f|5c|2e)/i', $path) === 1) {
            throw new RuntimeException('Request path is not a canonical local path.');
        }
        $route = parse_url($path, PHP_URL_PATH) ?: '/';
        foreach (explode('/', $route) as $segment) {
            if ($segment === '.' || $segment === '..') {
                throw new RuntimeException('Request path traversal is not allowed.');
            }
        }
        $allowed = false;
        if ($method === 'GET') {
            $allowed = in_array($route, ['/up', '/login', '/admin', '/admin/restrictions', '/admin/restrictions/import', '/admin/restrictions/create', '/admin/restrictions/publish', '/admin/restrictions/history', '/v1/manifest.json'], true)
                || preg_match('~^/admin/restrictions/imports/[1-9][0-9]*$~D', $route) === 1
                || preg_match('~^/admin/restrictions/[1-9][0-9]*/edit$~D', $route) === 1
                || preg_match('~^/storage/datasets/restrictions/[A-Za-z0-9._-]+/restrictions-[A-Za-z0-9._-]+\.json$~D', $route) === 1;
        } elseif ($method === 'POST') {
            $allowed = $route === '/login'
                || ($route === '/admin/restrictions/imports' && $multipart)
                || preg_match('~^/admin/restrictions/imports/[1-9][0-9]*/confirm$~D', $route) === 1
                || preg_match('~^/admin/restrictions/[1-9][0-9]*/(?:validate|approve-material-change)$~D', $route) === 1
                || in_array($route, ['/admin/restrictions/publish', '/admin/restrictions'], true);
            if (preg_match('~^/admin/restrictions/[1-9][0-9]*$~D', $route) === 1 && is_array($body)) {
                $allowed = array_key_exists('_method', $body) && is_string($body['_method']) && $body['_method'] === 'PUT' && ! $multipart;
            }
        }
        if (! $allowed) {
            throw new RuntimeException('HTTP method/path is outside the C31 editorial allowlist.');
        }
        if ($multipart && $route !== '/admin/restrictions/imports') {
            throw new RuntimeException('Multipart is allowed only for schema2 analysis.');
        }
    }
}

final class C31ReadOnlyDatabase
{
    private PDO $pdo;

    public function __construct(string $databasePath, string $instanceRoot)
    {
        if (! extension_loaded('pdo_sqlite')) {
            throw new RuntimeException('PDO SQLite extension is required for read-only snapshots.');
        }
        $realRoot = realpath($instanceRoot);
        $realDatabase = realpath($databasePath);
        if ($realRoot === false || $realDatabase === false || ! c31_is_under($realDatabase, $realRoot)
            || basename($realDatabase) !== 'picoradar.sqlite') {
            throw new RuntimeException('Read-only database path does not match the verified C31 instance.');
        }
        $uriPath = str_replace('\\', '/', $realDatabase);
        $uriPath = str_replace(['%', '?', '#', ' '], ['%25', '%3F', '%23', '%20'], $uriPath);
        $this->pdo = new PDO('sqlite:file:'.$uriPath.'?mode=ro', null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $this->pdo->exec('PRAGMA query_only=ON');
        if ((int) $this->pdo->query('PRAGMA query_only')->fetchColumn() !== 1) {
            throw new RuntimeException('SQLite query_only could not be enabled.');
        }
        $main = $this->pdo->query("PRAGMA database_list")->fetch();
        if (! is_array($main) || ! c31_same_path((string) ($main['file'] ?? ''), $realDatabase)) {
            throw new RuntimeException('Read-only SQLite opened an unexpected database.');
        }
    }

    public function one(string $sql, array $parameters = []): ?array
    {
        $statement = $this->pdo->prepare($sql);
        $statement->execute($parameters);
        $row = $statement->fetch();

        return is_array($row) ? $row : null;
    }

    public function all(string $sql, array $parameters = []): array
    {
        $statement = $this->pdo->prepare($sql);
        $statement->execute($parameters);

        return $statement->fetchAll();
    }

    public function scalar(string $sql, array $parameters = []): mixed
    {
        $statement = $this->pdo->prepare($sql);
        $statement->execute($parameters);

        return $statement->fetchColumn();
    }

    public static function samePath(string $left, string $right): bool
    {
        return c31_same_path($left, $right);
    }
}

function c31_same_path(string $left, string $right): bool
{
    return rtrim(str_replace('\\', '/', strtolower($left)), '/') === rtrim(str_replace('\\', '/', strtolower($right)), '/');
}

function c31_safe_exception(Throwable $error): string
{
    $message = $error->getMessage();
    foreach ([
        'PICORADAR_EDITOR_PASSWORD', 'PICORADAR_OPERATOR_PASSWORD',
        'PICORADAR_C31_EDITOR_PASSWORD', 'PICORADAR_C31_SUPERADMIN_PASSWORD',
        'PICORADAR_C31_EDITOR_EMAIL', 'PICORADAR_C31_SUPERADMIN_EMAIL',
    ] as $name) {
        $secret = getenv($name);
        if (is_string($secret) && $secret !== '') {
            $message = str_replace($secret, '<redacted>', $message);
        }
    }
    $message = preg_replace('~[A-Za-z]:[\\/][^\s,;]+~', '<local-path>', $message) ?? 'UNAVAILABLE';
    $message = preg_replace('/(?i)(password|_token|xsrf-token|cookie|authorization)\s*[:=]\s*[^\s,&]+/', '$1=<redacted>', $message) ?? 'UNAVAILABLE';
    $message = preg_replace('/[\x00-\x1F\x7F]+/', ' ', $message) ?? 'UNAVAILABLE';

    return substr(trim($message), 0, 200);
}

final class C31EditorialWorkflow
{
    private string $origin;
    private string $instanceRoot;
    private string $privateRoot;
    private string $publicRoot;
    private C31ReadOnlyDatabase $db;
    private C31HttpClient $editor;
    private C31HttpClient $reviewer;
    private array $stateBeforePublish = [];
    private array $pointerBeforeImport = [];
    private int $syntheticJurisdictionId = 0;
    private string $manifestSha = '';

    public function run(): void
    {
        $config = $this->preflight();
        $this->origin = $config['origin'];
        $this->instanceRoot = $config['instanceRoot'];
        $this->privateRoot = $config['privateRoot'];
        $this->publicRoot = $config['publicRoot'];
        $this->db = $config['db'];
        $editorId = $config['editorId'];
        $reviewerId = $config['reviewerId'];
        $this->assertFreshBaseline($editorId, $reviewerId);
        $fixture = c31_build_fixture(new DateTimeImmutable('now', new DateTimeZone('UTC')), bin2hex(random_bytes(8)));
        $fixtureBytes = c31_fixture_bytes($fixture);
        $fixturePath = $this->writeFixture($fixtureBytes, $fixture['version']);
        $fixtureSha = hash('sha256', $fixtureBytes);
        c31_log('C_FIXTURE', 'PASS version='.$fixture['version'].' bytes='.strlen($fixtureBytes).' sha256='.$fixtureSha.' source=example.test');

        $this->editor = new C31HttpClient($this->origin, 'EDITOR');
        $this->reviewer = new C31HttpClient($this->origin, 'SUPERADMIN');
        try {
            $health = $this->editor->request('GET', '/up');
            if ($health['status'] !== 200) {
                c31_fail('C_PREP', 'INSTANCE_HEALTHCHECK_NOT_200');
            }
            c31_log('C_PREP', 'PASS instance_id='.$config['instanceId'].' mode=EDITORIAL_QA port='.$config['port']);
            $this->login($this->editor, (string) $config['editorEmail'], (string) $config['editorPassword']);
            $this->login($this->reviewer, (string) $config['reviewerEmail'], (string) $config['reviewerPassword']);
            $importId = $this->analyzeImport($fixturePath, $fixtureSha, $editorId);
            $draftId = $this->confirmImport($importId, $editorId);
            $this->assertHttpGuards($draftId, $editorId);
            $this->validateAndApprove($draftId, $editorId, $reviewerId, $fixture);
            $published = $this->publish($draftId, $fixture, $reviewerId);
            $this->liveBytes($published);
            $this->manualCreateAndUpdate($fixture, $editorId, $published);
            c31_log('C_IMPORT_ANALYZE', 'PASS import_id='.$importId);
            c31_log('C_CONFIRM_DRAFT', 'PASS draft_id='.$draftId);
            c31_log('C_APPROVAL', 'PASS independent_actor_id='.$reviewerId);
            c31_log('C_PUBLISH', 'PASS version='.$published['version'].' revision='.$published['publication_revision']);
            c31_log('C_LIVE_BYTES', 'PASS manifest_sha256='.$this->manifestSha.' payload_sha256='.$published['sha256']);
            c31_log('C_MANUAL_CREATE', 'PASS draft_id='.$this->manualDraftId);
            c31_log('C_MANUAL_UPDATE', 'PASS draft_id='.$this->manualDraftId.' status=draft OFF=true partial=true');
        } finally {
            $this->editor->close();
            $this->reviewer->close();
        }
    }

    public function resumeConfirmed(): void
    {
        $config = $this->preflight(true);
        $this->origin = $config['origin'];
        $this->instanceRoot = $config['instanceRoot'];
        $this->privateRoot = $config['privateRoot'];
        $this->publicRoot = $config['publicRoot'];
        $this->db = $config['db'];
        $editorId = $config['editorId'];
        $reviewerId = $config['reviewerId'];
        $state = $this->loadConfirmedState($config);
        $fixture = $state['fixture'];
        $importId = $state['importId'];
        $draftId = $state['draftId'];

        $this->editor = new C31HttpClient($this->origin, 'EDITOR');
        $this->reviewer = new C31HttpClient($this->origin, 'SUPERADMIN');
        try {
            $health = $this->editor->request('GET', '/up');
            $this->expectStatus('C_RESUME', $health, [200]);
            $this->login($this->editor, (string) $config['editorEmail'], (string) $config['editorPassword']);
            $this->login($this->reviewer, (string) $config['reviewerEmail'], (string) $config['reviewerPassword']);
            c31_log('C_RESUME', 'PASS import_id='.$importId.' draft_id='.$draftId.' preserved_without_reimport=true');
            $this->assertHttpGuards($draftId, $editorId);
            $this->validateAndApprove($draftId, $editorId, $reviewerId, $fixture);
            $published = $this->publish($draftId, $fixture, $reviewerId);
            $this->liveBytes($published);
            $this->manualCreateAndUpdate($fixture, $editorId, $published);
            c31_log('C_APPROVAL', 'PASS independent_actor_id='.$reviewerId);
            c31_log('C_PUBLISH', 'PASS version='.$published['version'].' revision='.$published['publication_revision']);
            c31_log('C_LIVE_BYTES', 'PASS manifest_sha256='.$this->manifestSha.' payload_sha256='.$published['sha256']);
            c31_log('C_MANUAL_CREATE', 'PASS draft_id='.$this->manualDraftId);
            c31_log('C_MANUAL_UPDATE', 'PASS draft_id='.$this->manualDraftId.' status=draft OFF=true partial=true');
        } finally {
            $this->editor->close();
            $this->reviewer->close();
        }
    }

    private ?int $manualDraftId = null;

    private function preflight(bool $resumeConfirmed = false): array
    {
        if (getenv('PICORADAR_EDITORIAL_QA') !== '1') {
            c31_fail('C_PREP', 'EDITORIAL_QA_FLAG_MISSING');
        }
        $instanceRoot = realpath((string) getenv('PICORADAR_INSTANCE_ROOT'));
        $instanceId = (string) getenv('PICORADAR_INSTANCE_ID');
        $expectedId = (string) getenv('PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID');
        if ($instanceRoot === false || $instanceId === '' || $instanceId !== $expectedId) {
            c31_fail('C_PREP', 'INSTANCE_ID_OR_ROOT_MISMATCH');
        }
        $instanceMarkerPath = $instanceRoot.DIRECTORY_SEPARATOR.'instance.json';
        $editorialMarkerPath = $instanceRoot.DIRECTORY_SEPARATOR.'runtime'.DIRECTORY_SEPARATOR.'editorial-qa.json';
        $processMarkerPath = $instanceRoot.DIRECTORY_SEPARATOR.'runtime'.DIRECTORY_SEPARATOR.'process.json';
        $instance = is_file($instanceMarkerPath) ? json_decode((string) file_get_contents($instanceMarkerPath), true) : null;
        $editorial = is_file($editorialMarkerPath) ? json_decode((string) file_get_contents($editorialMarkerPath), true) : null;
        $process = is_file($processMarkerPath) ? json_decode((string) file_get_contents($processMarkerPath), true) : null;
        if (! is_array($instance) || ! is_array($editorial)
            || ($instance['id'] ?? null) !== $instanceId
            || ($instance['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
            || ($editorial['format'] ?? null) !== 'picoradar-editorial-qa/1'
            || ($editorial['scope'] ?? null) !== 'NON_PRODUCTION_SYNTHETIC'
            || ($editorial['prepared'] ?? null) !== true
            || ($editorial['instance_id'] ?? null) !== $instanceId
            || ! is_array($process) || ($process['format'] ?? null) !== 'picoradar-local-process/1'
            || ($process['instanceId'] ?? null) !== $instanceId || ($process['mode'] ?? null) !== 'EDITORIAL_QA'
            || ($process['entry_mode'] ?? null) !== ($editorial['entry_mode'] ?? null)
            || (int) ($process['pid'] ?? 0) < 1 || (int) ($process['port'] ?? 0) < 1024) {
            c31_fail('C_PREP', 'EDITORIAL_MARKER_MISMATCH');
        }
        $repoRoot = realpath(dirname(__DIR__, 3));
        if ($repoRoot === false || c31_is_under($instanceRoot, $repoRoot)) {
            c31_fail('C_PREP', 'INSTANCE_ROOT_INSIDE_CANDIDATE');
        }
        $privateRoot = realpath((string) getenv('PICORADAR_C31_PRIVATE_ROOT'));
        if ($privateRoot === false || c31_is_under($privateRoot, $repoRoot) || c31_is_under($privateRoot, $instanceRoot)) {
            c31_fail('C_PREP', 'PRIVATE_ROOT_INVALID');
        }
        $fixturePaths = glob($privateRoot.DIRECTORY_SEPARATOR.'c31-qa-*.json') ?: [];
        if ((! $resumeConfirmed && $fixturePaths !== []) || ($resumeConfirmed && count($fixturePaths) !== 1)) {
            c31_fail('C_PREP', 'C31_FIXTURE_ALREADY_EXISTS_NO_AUTOMATIC_RERUN');
        }
        $fixturePath = $fixturePaths[0] ?? null;
        if ($fixturePath !== null && (is_link($fixturePath) || ! is_file($fixturePath))) {
            c31_fail('C_PREP', 'C31_FIXTURE_PATH_NOT_REGULAR_FILE');
        }
        $baseUrl = (string) getenv('PICORADAR_C31_BASE_URL');
        $parts = parse_url($baseUrl);
        if (! is_array($parts) || strtolower((string) ($parts['scheme'] ?? '')) !== 'http'
            || strtolower((string) ($parts['host'] ?? '')) !== '127.0.0.1'
            || ! isset($parts['port']) || (int) $parts['port'] < 1024 || (int) $parts['port'] > 65535
            || isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment'])
            || ! in_array($parts['path'] ?? '', ['', '/'], true)) {
            c31_fail('C_PREP', 'BASE_URL_MUST_BE_EXACT_LOOPBACK_HTTP');
        }
        $origin = 'http://127.0.0.1:'.(int) $parts['port'];
        if ((int) $process['port'] !== (int) $parts['port']) {
            c31_fail('C_PREP', 'BASE_URL_PORT_DOES_NOT_MATCH_PROCESS_MARKER');
        }
        $publicRoot = realpath($instanceRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public');
        $databasePath = $instanceRoot.DIRECTORY_SEPARATOR.'data'.DIRECTORY_SEPARATOR.'picoradar.sqlite';
        if ($publicRoot === false || ! c31_is_under($publicRoot, $instanceRoot) || ! is_file($databasePath)) {
            c31_fail('C_PREP', 'INSTANCE_STORAGE_OR_DATABASE_MISSING');
        }
        $db = new C31ReadOnlyDatabase($databasePath, $instanceRoot);
        $editorEmail = (string) (getenv('PICORADAR_C31_EDITOR_EMAIL') ?: 'editor-c31@picoradar.test');
        $editorPassword = (string) (getenv('PICORADAR_C31_EDITOR_PASSWORD') ?: getenv('PICORADAR_EDITOR_PASSWORD'));
        $reviewerEmail = (string) (getenv('PICORADAR_C31_SUPERADMIN_EMAIL') ?: 'superadmin@picoradar.test');
        $reviewerPassword = (string) (getenv('PICORADAR_C31_SUPERADMIN_PASSWORD') ?: getenv('PICORADAR_OPERATOR_PASSWORD'));
        if ($editorEmail === '' || $editorPassword === '' || $reviewerEmail === '' || $reviewerPassword === '') {
            c31_fail('C_PREP', 'SYNTHETIC_OPERATOR_CREDENTIALS_MISSING');
        }
        $editor = $db->one('SELECT id, role, is_active FROM users WHERE email = ?', [$editorEmail]);
        $reviewer = $db->one('SELECT id, role, is_active FROM users WHERE email = ?', [$reviewerEmail]);
        if (! $editor || ! $reviewer || (int) $editor['is_active'] !== 1 || (int) $reviewer['is_active'] !== 1
            || $editor['role'] !== 'editor' || $reviewer['role'] !== 'super_admin' || (int) $editor['id'] === (int) $reviewer['id']) {
            c31_fail('C_PREP', 'SYNTHETIC_OPERATOR_ROLES_NOT_DISTINCT');
        }

        return [
            'origin' => $origin,
            'instanceRoot' => $instanceRoot,
            'privateRoot' => $privateRoot,
            'publicRoot' => $publicRoot,
            'db' => $db,
            'editorId' => (int) $editor['id'],
            'reviewerId' => (int) $reviewer['id'],
            'editorEmail' => $editorEmail,
            'editorPassword' => $editorPassword,
            'reviewerEmail' => $reviewerEmail,
            'reviewerPassword' => $reviewerPassword,
            'instanceId' => $instanceId,
            'port' => (int) $parts['port'],
            'fixturePath' => $fixturePath,
        ];
    }

    private function loadConfirmedState(array $config): array
    {
        $path = $config['fixturePath'];
        if (! is_string($path) || filesize($path) === false || filesize($path) > 64 * 1024) {
            c31_fail('C_RESUME', 'EXISTING_SYNTHETIC_FIXTURE_INVALID');
        }
        $bytes = file_get_contents($path);
        $fixture = is_string($bytes) ? json_decode($bytes, true) : null;
        $fixtureVersion = is_array($fixture) ? (string) ($fixture['version'] ?? '') : '';
        if (! is_array($fixture) || preg_match('/^c31-qa-[a-f0-9]{16}$/D', $fixtureVersion) !== 1
            || basename($path) !== $fixtureVersion.'.json' || ($fixture['schemaVersion'] ?? null) !== 2
            || ($fixture['datasetKey'] ?? null) !== 'restrictions' || count($fixture['jurisdictions'] ?? []) !== 1) {
            c31_fail('C_RESUME', 'EXISTING_FIXTURE_CONTRACT_MISMATCH');
        }
        $jurisdictionFixture = $fixture['jurisdictions'][0];
        $coverage = $jurisdictionFixture['coverages'][0] ?? null;
        $rule = $coverage['rules'][0] ?? null;
        if (($jurisdictionFixture['id'] ?? null) !== 'c31-synthetic-off'
            || ($jurisdictionFixture['name'] ?? null) !== 'C31 Synthetic Jurisdiction OFF'
            || ($jurisdictionFixture['municipalityCodes'] ?? null) !== ['99999']
            || ($jurisdictionFixture['consultationEnabled'] ?? null) !== false
            || ! is_array($coverage) || ($coverage['consultationEnabled'] ?? null) !== false
            || ($coverage['coverageCompleteness'] ?? null) !== 'partial'
            || ($rule['id'] ?? null) !== 'C31_SYNTHETIC_RESTRICTION_RULE'
            || ($rule['sourceUrl'] ?? null) !== 'https://example.test/c31-synthetic-restrictions') {
            c31_fail('C_RESUME', 'EXISTING_FIXTURE_NOT_C31_OFF_PARTIAL');
        }

        $sha = hash('sha256', $bytes);
        $import = $this->db->one(
            'SELECT id, original_name, status, row_count, valid_count, invalid_count, created_by_id, confirmed_by_id, report FROM restriction_imports WHERE sha256=?',
            [$sha],
        );
        $report = is_array($import) ? json_decode((string) $import['report'], true) : null;
        $draftIds = $report['confirmation']['draft_ids'] ?? null;
        if (! $import || $import['original_name'] !== basename($path) || $import['status'] !== 'confirmed'
            || (int) $import['row_count'] !== 1 || (int) $import['valid_count'] !== 1 || (int) $import['invalid_count'] !== 0
            || (int) $import['created_by_id'] !== $config['editorId'] || (int) $import['confirmed_by_id'] !== $config['editorId']
            || ! is_array($draftIds) || count($draftIds) !== 1 || ! is_numeric($draftIds[0]) || (int) $draftIds[0] < 1) {
            c31_fail('C_RESUME', 'EXISTING_IMPORT_NOT_CONFIRMED_BY_SYNTHETIC_EDITOR');
        }
        $importId = (int) $import['id'];
        $draftId = (int) $draftIds[0];
        $rows = $this->db->all(
            'SELECT id, state, publishable, jurisdiction_id FROM restriction_import_rows WHERE restriction_import_id=?',
            [$importId],
        );
        $jurisdiction = $this->db->one(
            "SELECT j.id, j.enabled, g.code, g.level FROM jurisdictions j JOIN geographic_units g ON g.id=j.primary_geographic_unit_id WHERE j.key='c31-synthetic-off'",
        );
        $version = $this->db->one(
            'SELECT id, status, created_by_id, jurisdiction_id, payload FROM restriction_rule_versions WHERE id=?',
            [$draftId],
        );
        $publicationState = $this->databasePublicationState();
        if (count($rows) !== 1 || $rows[0]['state'] !== 'valid' || (int) $rows[0]['publishable'] !== 1
            || ! $jurisdiction || (int) $jurisdiction['enabled'] !== 0 || $jurisdiction['code'] !== '99999'
            || $jurisdiction['level'] !== 'municipality' || (int) $rows[0]['jurisdiction_id'] !== (int) $jurisdiction['id']
            || ! $version || $version['status'] !== 'draft' || (int) $version['created_by_id'] !== $config['editorId']
            || (int) $version['jurisdiction_id'] !== (int) $jurisdiction['id']
            || ! $this->payloadIsOffPartial((string) $version['payload'], implode(',', $rule['digits'] ?? []))
            || $publicationState['current_version'] !== null || $publicationState['publication_revision'] !== 0
            || $publicationState['release_count'] !== 0 || $publicationState['publication_count'] !== 0
            || (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_imports') !== 1
            || (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_rule_versions WHERE jurisdiction_id=?', [(int) $jurisdiction['id']]) !== 1) {
            c31_fail('C_RESUME', 'CONFIRMED_DRAFT_OR_PUBLICATION_STATE_UNEXPECTED');
        }
        $this->syntheticJurisdictionId = (int) $jurisdiction['id'];
        $this->pointerBeforeImport = $publicationState;
        c31_log('C_RESUME_SNAPSHOT', 'PASS current=null revision=0 releases=0 publications=0 imports=1 draft=OFF/partial');

        return ['fixture' => $fixture, 'importId' => $importId, 'draftId' => $draftId];
    }

    private function writeFixture(string $bytes, string $version): string
    {
        if (preg_match('/^c31-qa-[a-f0-9]{16}$/D', $version) !== 1) {
            c31_fail('C_FIXTURE', 'FIXTURE_VERSION_INVALID');
        }
        $path = $this->privateRoot.DIRECTORY_SEPARATOR.$version.'.json';
        $handle = @fopen($path, 'xb');
        if ($handle === false) {
            c31_fail('C_FIXTURE', 'FIXTURE_PATH_ALREADY_EXISTS_OR_NOT_WRITABLE');
        }
        try {
            if (fwrite($handle, $bytes) !== strlen($bytes) || ! fflush($handle)) {
                c31_fail('C_FIXTURE', 'FIXTURE_WRITE_INCOMPLETE');
            }
        } finally {
            fclose($handle);
        }

        return $path;
    }

    private function assertFreshBaseline(int $editorId, int $reviewerId): void
    {
        $dataset = $this->db->one("SELECT id, schema_version, enabled, current_version, publication_revision FROM datasets WHERE key='restrictions'");
        $jurisdiction = $this->db->one("SELECT j.id, j.enabled, g.code, g.level FROM jurisdictions j LEFT JOIN geographic_units g ON g.id=j.primary_geographic_unit_id WHERE j.key='c31-synthetic-off'");
        if (! $dataset || (int) $dataset['schema_version'] !== 2 || (int) $dataset['enabled'] !== 1
            || $dataset['current_version'] !== null || (int) $dataset['publication_revision'] !== 0) {
            c31_fail('C_PREP', 'RESTRICTIONS_DATASET_NOT_FRESH_SCHEMA2_ENABLED');
        }
        if (! $jurisdiction || (int) $jurisdiction['enabled'] !== 0 || $jurisdiction['code'] !== '99999' || $jurisdiction['level'] !== 'municipality') {
            c31_fail('C_PREP', 'SYNTHETIC_OFF_JURISDICTION_MISMATCH');
        }
        $source = $this->db->one("SELECT s.id, s.is_active FROM sources s WHERE s.dataset_id=? AND s.url='https://example.test/c31-synthetic-restrictions'", [(int) $dataset['id']]);
        if (! $source || (int) $source['is_active'] !== 1) {
            c31_fail('C_PREP', 'SYNTHETIC_SOURCE_NOT_REGISTERED_ACTIVE');
        }
        $releaseCount = (int) $this->db->scalar('SELECT COUNT(*) FROM dataset_releases WHERE dataset_id=?', [(int) $dataset['id']]);
        $publicationCount = (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_publications rp JOIN dataset_releases dr ON dr.id=rp.dataset_release_id WHERE dr.dataset_id=?', [(int) $dataset['id']]);
        $versionCount = (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_rule_versions WHERE jurisdiction_id=?', [(int) $jurisdiction['id']]);
        $priorC31Imports = (int) $this->db->scalar("SELECT COUNT(*) FROM restriction_imports WHERE original_name LIKE 'c31-qa-%'");
        if ($releaseCount !== 0 || $publicationCount !== 0 || $versionCount !== 0 || $priorC31Imports !== 0 || $editorId === $reviewerId) {
            c31_fail('C_PREP', 'SYNTHETIC_START_STATE_NOT_EMPTY');
        }
        $this->syntheticJurisdictionId = (int) $jurisdiction['id'];
        $this->pointerBeforeImport = $this->databasePublicationState();
        c31_log('C_PRE_SNAPSHOT', 'current=null revision=0 releases=0 publications=0 jurisdiction=OFF/99999 versions=0');
    }

    private function login(C31HttpClient $client, string $email, string $password): void
    {
        $page = $client->request('GET', '/login');
        $this->expectStatus('C_LOGIN', $page, [200]);
        $form = c31_parse_html_form($page['body'], '/login');
        $token = $form['hidden']['_token'] ?? '';
        if ($token === '') {
            c31_fail('C_LOGIN', 'LOGIN_CSRF_FORM_MISSING');
        }
        $response = $client->request('POST', '/login', ['_token' => $token, 'email' => $email, 'password' => $password], '/login');
        $location = $this->redirectLocation('C_LOGIN', $response, '~^/admin$~D');
        $dashboard = $client->request('GET', $location);
        $this->expectStatus('C_LOGIN', $dashboard, [200]);
        if (stripos($dashboard['body'], 'PicoRadar Control Plane') === false) {
            c31_fail('C_LOGIN', 'AUTHENTICATED_ADMIN_PAGE_NOT_RENDERED');
        }
    }

    private function analyzeImport(string $fixturePath, string $fixtureSha, int $editorId): int
    {
        if ($this->db->one('SELECT id FROM restriction_imports WHERE sha256=?', [$fixtureSha])) {
            c31_fail('C_IMPORT_ANALYZE', 'FIXTURE_IMPORT_ALREADY_EXISTS');
        }
        $formPage = $this->editor->request('GET', '/admin/restrictions/import');
        $this->expectStatus('C_IMPORT_ANALYZE', $formPage, [200]);
        $form = c31_parse_html_form($formPage['body'], '/admin/restrictions/imports');
        $token = $form['hidden']['_token'] ?? '';
        if ($token === '') {
            c31_fail('C_IMPORT_ANALYZE', 'IMPORT_CSRF_FORM_MISSING');
        }
        $file = new CURLFile($fixturePath, 'application/json', basename($fixturePath));
        $response = $this->editor->request('POST', '/admin/restrictions/imports', ['_token' => $token, 'file' => $file], '/admin/restrictions/import', true);
        $location = $this->redirectLocation('C_IMPORT_ANALYZE', $response, '~^/admin/restrictions/imports/([1-9][0-9]*)$~D');
        preg_match('~^/admin/restrictions/imports/([1-9][0-9]*)$~D', parse_url($location, PHP_URL_PATH) ?: '', $match);
        $importId = (int) ($match[1] ?? 0);
        if ($importId < 1) {
            c31_fail('C_IMPORT_ANALYZE', 'IMPORT_REVIEW_ID_MISSING');
        }
        $review = $this->editor->request('GET', $location);
        $this->expectStatus('C_IMPORT_ANALYZE', $review, [200]);
        $rowId = c31_select_publishable_row_id($review['body']);
        $import = $this->db->one('SELECT id, status, valid_count, invalid_count, sha256, created_by_id FROM restriction_imports WHERE id=?', [$importId]);
        $rows = $this->db->all('SELECT id, state, publishable, jurisdiction_id FROM restriction_import_rows WHERE restriction_import_id=?', [$importId]);
        if (! $import || $import['status'] !== 'analyzed' || $import['sha256'] !== $fixtureSha
            || (int) $import['created_by_id'] !== $editorId || (int) $import['valid_count'] !== 1 || (int) $import['invalid_count'] !== 0
            || count($rows) !== 1 || (string) $rows[0]['id'] !== $rowId || $rows[0]['state'] !== 'valid'
            || (int) $rows[0]['publishable'] !== 1) {
            c31_fail('C_IMPORT_ANALYZE', 'ANALYZED_IMPORT_DOES_NOT_MATCH_SYNTHETIC_FIXTURE');
        }
        if ((int) $rows[0]['jurisdiction_id'] !== $this->syntheticJurisdictionId
            || $this->databasePublicationState() !== $this->pointerBeforeImport
            || (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_rule_versions WHERE jurisdiction_id=?', [$this->syntheticJurisdictionId]) !== 0) {
            c31_fail('C_IMPORT_ANALYZE', 'ANALYSIS_CHANGED_DRAFT_OR_PUBLICATION_STATE');
        }
        $this->importRowId = (int) $rowId;
        c31_log('C_IMPORT_ANALYZE', 'PASS import_id='.$importId.' valid_row_id='.$rowId.' file_sha256='.$fixtureSha);

        return $importId;
    }

    private ?int $importRowId = null;

    private function assertHttpGuards(int $draftId, int $editorId): void
    {
        $editPath = '/admin/restrictions/'.$draftId.'/edit';
        $approvalPath = '/admin/restrictions/'.$draftId.'/approve-material-change';
        $beforeVersion = $this->db->one(
            'SELECT status, payload_sha256, updated_by_id, validated_by_id FROM restriction_rule_versions WHERE id=?',
            [$draftId],
        );
        $beforeApprovalCount = (int) $this->db->scalar(
            "SELECT COUNT(*) FROM audit_logs WHERE action='restriction.material_change.approved' AND subject_type='App\\Models\\RestrictionRuleVersion' AND subject_id=?",
            [$draftId],
        );
        $beforePublication = $this->databasePublicationState();
        if (! $beforeVersion || $beforeVersion['status'] !== 'draft' || (int) $beforeVersion['updated_by_id'] !== $editorId
            || $beforeVersion['validated_by_id'] !== null || $beforeApprovalCount !== 0) {
            c31_fail('A_HTTP', 'EDITORIAL_GUARD_PRECONDITION_NOT_CLEAN');
        }

        $csrfResponse = $this->editor->request('POST', $approvalPath, [
            'publication_revision' => '0',
            'reason' => 'C31 synthetic denial check only.',
            'evidence_url' => 'https://example.test/c31-synthetic-restrictions',
        ], $editPath);
        $this->expectStatus('A_HTTP', $csrfResponse, [419]);

        $edit = $this->editor->request('GET', $editPath);
        $this->expectStatus('A_HTTP', $edit, [200]);
        $form = c31_parse_html_form($edit['body'], '/admin/restrictions/'.$draftId);
        $token = $form['hidden']['_token'] ?? '';
        if ($token === '') {
            c31_fail('A_HTTP', 'EDITOR_CSRF_FORM_MISSING');
        }
        $editorResponse = $this->editor->request('POST', $approvalPath, [
            '_token' => $token,
            'publication_revision' => '0',
            'reason' => 'C31 synthetic denial check only.',
            'evidence_url' => 'https://example.test/c31-synthetic-restrictions',
        ], $editPath);
        $this->expectStatus('A_HTTP', $editorResponse, [403]);

        $blockedPostStatus = $this->probeNonAllowlistedPost();
        $afterVersion = $this->db->one(
            'SELECT status, payload_sha256, updated_by_id, validated_by_id FROM restriction_rule_versions WHERE id=?',
            [$draftId],
        );
        $afterApprovalCount = (int) $this->db->scalar(
            "SELECT COUNT(*) FROM audit_logs WHERE action='restriction.material_change.approved' AND subject_type='App\\Models\\RestrictionRuleVersion' AND subject_id=?",
            [$draftId],
        );
        if ($afterVersion !== $beforeVersion || $afterApprovalCount !== $beforeApprovalCount
            || $this->databasePublicationState() !== $beforePublication) {
            c31_fail('A_HTTP', 'DENIED_HTTP_PROBE_CHANGED_SYNTHETIC_STATE');
        }
        c31_log('A_HTTP', 'PASS missing_csrf='.$csrfResponse['status'].' editor_approve='.$editorResponse['status'].' non_allowlisted_post='.$blockedPostStatus.' state_unchanged=true');
    }

    private function probeNonAllowlistedPost(): int
    {
        $handle = curl_init($this->origin.'/admin/operators');
        if ($handle === false) {
            c31_fail('A_HTTP', 'NON_ALLOWLISTED_PROBE_CURL_INIT_FAILED');
        }
        $responseBytes = 0;
        $options = [
            CURLOPT_RETURNTRANSFER => false,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0,
            CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_PROXY => '',
            CURLOPT_NOPROXY => '*',
            CURLOPT_PROTOCOLS => CURLPROTO_HTTP,
            CURLOPT_CUSTOMREQUEST => 'POST',
            CURLOPT_POSTFIELDS => 'c31_probe=1',
            CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded', 'Accept: text/plain'],
            CURLOPT_WRITEFUNCTION => static function ($curl, string $chunk) use (&$responseBytes): int {
                $responseBytes += strlen($chunk);

                return $responseBytes <= 65536 ? strlen($chunk) : 0;
            },
        ];
        try {
            curl_setopt_array($handle, $options);
            if (curl_exec($handle) === false || $responseBytes > 65536) {
                c31_fail('A_HTTP', 'NON_ALLOWLISTED_PROBE_HTTP_FAILED_OR_TOO_LARGE');
            }
            $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        } finally {
            $handle = null;
        }
        if ($status !== 404) {
            c31_fail('A_HTTP', 'NON_ALLOWLISTED_POST_DID_NOT_RETURN_404');
        }

        return $status;
    }

    private function confirmImport(int $importId, int $editorId): int
    {
        $path = '/admin/restrictions/imports/'.$importId;
        $review = $this->editor->request('GET', $path);
        $this->expectStatus('C_CONFIRM_DRAFT', $review, [200]);
        $form = c31_parse_html_form($review['body'], $path.'/confirm');
        $token = $form['hidden']['_token'] ?? '';
        if ($token === '' || $this->importRowId === null) {
            c31_fail('C_CONFIRM_DRAFT', 'CONFIRM_FORM_OR_SELECTED_ROW_MISSING');
        }
        $selectedRow = c31_select_publishable_row_id($review['body']);
        if ((int) $selectedRow !== $this->importRowId) {
            c31_fail('C_CONFIRM_DRAFT', 'SELECTED_ROW_CHANGED_AFTER_ANALYSIS');
        }
        $response = $this->editor->request('POST', $path.'/confirm', ['_token' => $token, 'rows' => [$selectedRow]], $path);
        $location = $this->redirectLocation('C_CONFIRM_DRAFT', $response, '~^/admin/restrictions(?:\?.*)?$~D');
        $page = $this->editor->request('GET', $location);
        $this->expectStatus('C_CONFIRM_DRAFT', $page, [200]);
        $import = $this->db->one('SELECT status, confirmed_by_id, report FROM restriction_imports WHERE id=?', [$importId]);
        $report = is_array($import) ? json_decode((string) $import['report'], true) : null;
        $draftIds = $report['confirmation']['draft_ids'] ?? null;
        if (! is_array($draftIds) || count($draftIds) !== 1 || (int) $import['confirmed_by_id'] !== $editorId
            || (int) ($report['confirmation']['actor_id'] ?? 0) !== $editorId || $import['status'] !== 'confirmed'
            || $this->databasePublicationState() !== $this->pointerBeforeImport) {
            c31_fail('C_CONFIRM_DRAFT', 'CONFIRMATION_REPORT_DRAFT_ID_MISSING');
        }
        $draftId = (int) $draftIds[0];
        $version = $this->db->one('SELECT id, status, created_by_id, jurisdiction_id, payload FROM restriction_rule_versions WHERE id=?', [$draftId]);
        $payload = is_array($version) ? json_decode((string) $version['payload'], true) : null;
        $coverage = $payload['coverages'][0] ?? null;
        if (! $version || $version['status'] !== 'draft' || (int) $version['created_by_id'] !== $editorId
            || (int) $version['jurisdiction_id'] !== $this->syntheticJurisdictionId
            || ($payload['id'] ?? null) !== 'c31-synthetic-off' || ($payload['consultationEnabled'] ?? null) !== false
            || ($payload['municipalityCodes'] ?? null) !== ['99999']
            || ($coverage['consultationEnabled'] ?? null) !== false || ($coverage['coverageCompleteness'] ?? null) !== 'partial'
            || ($coverage['sourceUrls'][0] ?? null) !== 'https://example.test/c31-synthetic-restrictions'
            || ($coverage['rules'][0]['id'] ?? null) !== 'C31_SYNTHETIC_RESTRICTION_RULE'
            || count($coverage['rules'] ?? []) !== 1) {
            c31_fail('C_CONFIRM_DRAFT', 'CONFIRMED_DRAFT_NOT_OFF_PARTIAL');
        }
        c31_log('C_CONFIRM_DRAFT', 'PASS draft_id='.$draftId.' actor=Editor state=draft OFF=true partial=true');

        return $draftId;
    }

    private function validateAndApprove(int $draftId, int $editorId, int $reviewerId, array $fixture): void
    {
        $editPath = '/admin/restrictions/'.$draftId.'/edit';
        $edit = $this->reviewer->request('GET', $editPath);
        $this->expectStatus('C_APPROVAL', $edit, [200]);
        $editForm = c31_parse_html_form($edit['body'], '/admin/restrictions/'.$draftId);
        $token = $editForm['hidden']['_token'] ?? '';
        if ($token === '') {
            c31_fail('C_APPROVAL', 'VALIDATION_CSRF_FORM_MISSING');
        }
        $validatePath = '/admin/restrictions/'.$draftId.'/validate';
        $response = $this->reviewer->request('POST', $validatePath, ['_token' => $token], $editPath);
        $location = $this->redirectLocation('C_APPROVAL', $response, '~^/admin/restrictions/[1-9][0-9]*/edit$~D');
        $this->expectStatus('C_APPROVAL', $this->reviewer->request('GET', $location), [200]);
        $version = $this->db->one('SELECT status, created_by_id, updated_by_id, validated_by_id FROM restriction_rule_versions WHERE id=?', [$draftId]);
        if (! $version || $version['status'] !== 'validated' || (int) $version['created_by_id'] !== $editorId
            || (int) $version['validated_by_id'] !== $reviewerId || (int) $version['updated_by_id'] !== $editorId) {
            c31_fail('C_APPROVAL', 'VALIDATED_ACTOR_OR_STATE_MISMATCH');
        }
        $previewPath = '/admin/restrictions/publish?versions%5B0%5D='.$draftId;
        $preview = $this->reviewer->request('GET', $previewPath);
        $this->expectStatus('C_APPROVAL', $preview, [200]);
        $approvalPath = '/admin/restrictions/'.$draftId.'/approve-material-change';
        $approvalForm = c31_parse_html_form($preview['body'], $approvalPath);
        $revision = $approvalForm['hidden']['publication_revision'] ?? '';
        $approvalToken = $approvalForm['hidden']['_token'] ?? '';
        $source = $fixture['jurisdictions'][0]['coverages'][0]['sourceUrls'][0];
        if ($revision !== '0' || $approvalToken === '' || ! in_array($source, $approvalForm['options']['evidence_url'] ?? [], true)) {
            c31_fail('C_APPROVAL', 'APPROVAL_FORM_REVISION_OR_SOURCE_MISMATCH');
        }
        $reason = 'C31 synthetic editorial validation only; no legal conclusion.';
        $response = $this->reviewer->request('POST', $approvalPath, [
            '_token' => $approvalToken,
            'publication_revision' => $revision,
            'reason' => $reason,
            'evidence_url' => $source,
        ], $previewPath);
        $location = $this->redirectLocation('C_APPROVAL', $response, '~^/admin/restrictions/publish(?:\?.*)?$~D');
        $this->expectStatus('C_APPROVAL', $this->reviewer->request('GET', $location), [200]);
        $audit = $this->db->one("SELECT actor_id, action FROM audit_logs WHERE action='restriction.material_change.approved' AND subject_type='App\\Models\\RestrictionRuleVersion' AND subject_id=? ORDER BY id DESC LIMIT 1", [$draftId]);
        if (! $audit || (int) $audit['actor_id'] !== $reviewerId) {
            c31_fail('C_APPROVAL', 'INDEPENDENT_APPROVAL_AUDIT_MISSING');
        }
        c31_log('C_APPROVAL', 'PASS draft_id='.$draftId.' author_id='.$editorId.' reviewer_id='.$reviewerId.' revision=0');
    }

    private function publish(int $draftId, array $fixture, int $reviewerId): array
    {
        $previewPath = '/admin/restrictions/publish?versions%5B0%5D='.$draftId;
        $preview = $this->reviewer->request('GET', $previewPath);
        $this->expectStatus('C_PUBLISH', $preview, [200]);
        $form = c31_parse_html_form($preview['body'], '/admin/restrictions/publish');
        $revision = $form['hidden']['publication_revision'] ?? '';
        $token = $form['hidden']['_token'] ?? '';
        $versions = $form['values']['versions[]'] ?? [];
        if ($revision !== '0' || $token === '' || $versions !== [(string) $draftId]) {
            c31_fail('C_PUBLISH', 'PUBLISH_FORM_SELECTION_OR_REVISION_MISMATCH');
        }
        $response = $this->reviewer->request('POST', '/admin/restrictions/publish', [
            '_token' => $token,
            'publication_revision' => $revision,
            'versions' => [(string) $draftId],
        ], $previewPath);
        $location = $this->redirectLocation('C_PUBLISH', $response, '~^/admin/restrictions/history$~D');
        $this->expectStatus('C_PUBLISH', $this->reviewer->request('GET', $location), [200]);
        $dataset = $this->db->one("SELECT id, current_version, publication_revision FROM datasets WHERE key='restrictions'");
        if (! $dataset || (int) $dataset['publication_revision'] !== 1 || $dataset['current_version'] === null) {
            c31_fail('C_PUBLISH', 'PUBLISHED_DATASET_POINTER_NOT_REVISION_ONE');
        }
        $release = $this->db->one('SELECT id, version, status, asset_path, sha256 FROM dataset_releases WHERE dataset_id=? AND version=?', [(int) $dataset['id'], $dataset['current_version']]);
        $publication = $this->db->one('SELECT id, actor_id, result_publication_revision FROM restriction_publications WHERE dataset_release_id=?', [(int) ($release['id'] ?? 0)]);
        $item = $this->db->one('SELECT restriction_rule_version_id FROM restriction_publication_items WHERE restriction_publication_id=?', [(int) ($publication['id'] ?? 0)]);
        if (! $release || $release['status'] !== 'published' || ! $release['asset_path'] || ! preg_match('/^[a-f0-9]{64}$/D', $release['sha256'])
            || ! $publication || (int) $publication['actor_id'] !== $reviewerId || (int) $publication['result_publication_revision'] !== 1
            || ! $item || (int) $item['restriction_rule_version_id'] !== $draftId) {
            c31_fail('C_PUBLISH', 'RELEASE_PUBLICATION_ITEM_OR_ACTOR_MISMATCH');
        }
        $this->stateBeforePublish = [
            'current_version' => $dataset['current_version'],
            'publication_revision' => (int) $dataset['publication_revision'],
            'release_count' => (int) $this->db->scalar('SELECT COUNT(*) FROM dataset_releases WHERE dataset_id=?', [(int) $dataset['id']]),
            'publication_count' => (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_publications rp JOIN dataset_releases dr ON dr.id=rp.dataset_release_id WHERE dr.dataset_id=?', [(int) $dataset['id']]),
            'version' => $release['version'],
            'sha256' => $release['sha256'],
            'asset_path' => $release['asset_path'],
        ];

        return $this->stateBeforePublish;
    }

    private function liveBytes(array $published): void
    {
        $publicClient = new C31HttpClient($this->origin, 'PUBLIC');
        try {
        $manifest = $publicClient->request('GET', '/v1/manifest.json');
        $this->expectStatus('C_LIVE_BYTES', $manifest, [200]);
        if (strlen($manifest['body']) > 64 * 1024 || in_array(strtolower((string) ($manifest['headers']['content-encoding'] ?? 'identity')), ['gzip', 'br', 'deflate'], true)) {
            c31_fail('C_LIVE_BYTES', 'LIVE_MANIFEST_EXCEEDS_LIMIT_OR_IS_ENCODED');
        }
        $manifestPath = $this->publicRoot.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1'.DIRECTORY_SEPARATOR.'manifest.json';
        if (! is_file($manifestPath)) {
            c31_fail('C_LIVE_BYTES', 'LIVE_MANIFEST_STORAGE_FILE_MISSING');
        }
        $diskManifest = file_get_contents($manifestPath);
        $manifestSha = hash('sha256', $manifest['body']);
        if (! is_string($diskManifest) || ! hash_equals(hash('sha256', $diskManifest), $manifestSha)) {
            c31_fail('C_LIVE_BYTES', 'LIVE_MANIFEST_BYTES_DIFFER_FROM_STORAGE');
        }
        $decoded = json_decode($manifest['body'], true);
        $entry = $decoded['datasets']['restrictions'] ?? null;
        if (! is_array($entry) || ($entry['version'] ?? null) !== $published['version']
            || (int) ($entry['publicationRevision'] ?? -1) !== $published['publication_revision']
            || ($entry['sha256'] ?? null) !== $published['sha256']) {
            c31_fail('C_LIVE_BYTES', 'LIVE_MANIFEST_RELEASE_METADATA_MISMATCH');
        }
        $assetPath = (string) ($published['asset_path'] ?? '');
        if ($assetPath === '' || str_contains($assetPath, '..') || str_starts_with($assetPath, '/') || str_contains($assetPath, '\\')) {
            c31_fail('C_LIVE_BYTES', 'RELEASE_ASSET_PATH_INVALID');
        }
        $localAsset = realpath($this->publicRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $assetPath));
        if ($localAsset === false || ! c31_is_under($localAsset, $this->publicRoot)) {
            c31_fail('C_LIVE_BYTES', 'RELEASE_ASSET_OUTSIDE_PUBLIC_STORAGE');
        }
        $storagePayload = file_get_contents($localAsset);
        if (! is_string($storagePayload) || ! hash_equals($published['sha256'], hash('sha256', $storagePayload))) {
            c31_fail('C_LIVE_BYTES', 'PAYLOAD_STORAGE_HASH_MISMATCH');
        }
        $url = (string) ($entry['url'] ?? '');
        $expectedUrl = '/storage/'.$assetPath;
        if ($url !== $expectedUrl || preg_match('~^/storage/datasets/restrictions/[A-Za-z0-9._-]+/restrictions-[A-Za-z0-9._-]+\.json$~D', $url) !== 1) {
            c31_fail('C_LIVE_BYTES', 'MANIFEST_PAYLOAD_URL_INVALID');
        }
        $payloadResponse = $publicClient->request('GET', $url);
        $this->expectStatus('C_LIVE_BYTES', $payloadResponse, [200]);
        if (strlen($payloadResponse['body']) > 4 * 1024 * 1024 || in_array(strtolower((string) ($payloadResponse['headers']['content-encoding'] ?? 'identity')), ['gzip', 'br', 'deflate'], true)) {
            c31_fail('C_LIVE_BYTES', 'LIVE_PAYLOAD_EXCEEDS_LIMIT_OR_IS_ENCODED');
        }
        if (! hash_equals($published['sha256'], hash('sha256', $payloadResponse['body']))
            || ! hash_equals(hash('sha256', $storagePayload), hash('sha256', $payloadResponse['body']))) {
            c31_fail('C_LIVE_BYTES', 'LIVE_PAYLOAD_BYTES_DIFFER_FROM_RELEASE');
        }
        $payload = json_decode($payloadResponse['body'], true);
        $jurisdiction = null;
        foreach ($payload['jurisdictions'] ?? [] as $candidate) {
            if (($candidate['id'] ?? null) === 'c31-synthetic-off') {
                $jurisdiction = $candidate;
                break;
            }
        }
        $coverage = $jurisdiction['coverages'][0] ?? null;
        if (! is_array($jurisdiction) || ($jurisdiction['consultationEnabled'] ?? null) !== false
            || ($coverage['consultationEnabled'] ?? null) !== false || ($coverage['coverageCompleteness'] ?? null) !== 'partial'
            || count($coverage['rules'] ?? []) !== 1) {
            c31_fail('C_LIVE_BYTES', 'LIVE_PAYLOAD_NOT_OFF_PARTIAL');
        }
        $this->manifestSha = $manifestSha;
        c31_log('C_LIVE_BYTES', 'PASS manifest_bytes='.strlen($manifest['body']).' manifest_type='.($manifest['headers']['content-type'] ?? 'missing').' manifest_sha256='.$manifestSha.' payload_bytes='.strlen($payloadResponse['body']).' payload_type='.($payloadResponse['headers']['content-type'] ?? 'missing').' payload_sha256='.$published['sha256'].' version='.$published['version'].' revision='.$published['publication_revision']);
        } finally {
            $publicClient->close();
        }
    }

    private function manualCreateAndUpdate(array $fixture, int $editorId, array $published): void
    {
        $jurisdiction = $this->db->one("SELECT id, enabled FROM jurisdictions WHERE key='c31-synthetic-off'");
        if (! $jurisdiction || (int) $jurisdiction['enabled'] !== 0) {
            c31_fail('C_MANUAL_CREATE', 'SYNTHETIC_JURISDICTION_NOT_OFF');
        }
        $before = $this->databasePublicationState();
        if ($before !== $this->stateBeforePublish) {
            c31_fail('C_MANUAL_CREATE', 'PUBLICATION_STATE_CHANGED_BEFORE_MANUAL_FORM');
        }
        $createPath = '/admin/restrictions/create?jurisdiction_id='.(int) $jurisdiction['id'];
        $create = $this->editor->request('GET', $createPath);
        $this->expectStatus('C_MANUAL_CREATE', $create, [200]);
        $createForm = c31_parse_html_form($create['body'], '/admin/restrictions');
        c31_require_form_names($createForm, [
            '_token', 'jurisdiction_id', 'consultation_enabled', 'coverages[0][pair]',
            'coverages[0][verified_at]', 'coverages[0][stale_after]', 'coverages[0][source_urls]',
            'coverages[0][rules][0][id]', 'coverages[0][rules][0][digits]',
            'coverages[0][rules][0][conditions_json]',
        ]);
        if (($createForm['selects']['jurisdiction_id'][0] ?? null) !== (string) $jurisdiction['id']) {
            c31_fail('C_MANUAL_CREATE', 'CREATE_FORM_DID_NOT_PRESELECT_SYNTHETIC_JURISDICTION');
        }
        $token = $createForm['hidden']['_token'] ?? '';
        $fields = c31_build_manual_fields($fixture, (int) $jurisdiction['id'], '1,2', false);
        $fields['_token'] = $token;
        $response = $this->editor->request('POST', '/admin/restrictions', $fields, '/admin/restrictions/create');
        $location = $this->redirectLocation('C_MANUAL_CREATE', $response, '~^/admin/restrictions/[1-9][0-9]*/edit$~D');
        preg_match('~^/admin/restrictions/([1-9][0-9]*)/edit$~D', $location, $match);
        $draftId = (int) ($match[1] ?? 0);
        if ($draftId < 1) {
            c31_fail('C_MANUAL_CREATE', 'MANUAL_DRAFT_REDIRECT_ID_MISSING');
        }
        $edit = $this->editor->request('GET', $location);
        $this->expectStatus('C_MANUAL_CREATE', $edit, [200]);
        $version = $this->db->one('SELECT id, status, created_by_id, jurisdiction_id, payload, payload_sha256 FROM restriction_rule_versions WHERE id=?', [$draftId]);
        if (! $version || $version['status'] !== 'draft' || (int) $version['created_by_id'] !== $editorId
            || (int) $version['jurisdiction_id'] !== (int) $jurisdiction['id'] || !$this->payloadIsOffPartial($version['payload'], '1,2')) {
            c31_fail('C_MANUAL_CREATE', 'MANUAL_DRAFT_NOT_OFF_PARTIAL');
        }
        $beforeHash = (string) $version['payload_sha256'];
        c31_log('C_MANUAL_CREATE', 'PASS draft_id='.$draftId.' state=draft OFF=true partial=true');

        $editForm = c31_parse_html_form($edit['body'], '/admin/restrictions/'.$draftId);
        c31_require_form_names($editForm, ['_token', '_method', 'coverages[0][rules][0][digits]']);
        if (($editForm['hidden']['_method'] ?? '') !== 'PUT') {
            c31_fail('C_MANUAL_UPDATE', 'EDIT_FORM_METHOD_OVERRIDE_NOT_PUT');
        }
        $fields = $editForm['submission'];
        if (($fields['coverages[0][rules][0][digits]'] ?? null) !== '1,2' || ($fields['_method'] ?? null) !== 'PUT') {
            c31_fail('C_MANUAL_UPDATE', 'EDIT_FORM_INITIAL_VALUES_DO_NOT_MATCH_SYNTHETIC_DRAFT');
        }
        $fields['coverages[0][rules][0][digits]'] = '1,2,3';
        $updatePath = '/admin/restrictions/'.$draftId;
        $response = $this->editor->request('POST', $updatePath, $fields, $location);
        $updateLocation = $this->redirectLocation('C_MANUAL_UPDATE', $response, '~^/admin/restrictions/[1-9][0-9]*/edit$~D');
        $updatedPage = $this->editor->request('GET', $updateLocation);
        $this->expectStatus('C_MANUAL_UPDATE', $updatedPage, [200]);
        $updated = $this->db->one('SELECT status, payload, payload_sha256, created_by_id FROM restriction_rule_versions WHERE id=?', [$draftId]);
        if (! $updated || $updated['status'] !== 'draft' || (int) $updated['created_by_id'] !== $editorId
            || $updated['payload_sha256'] === $beforeHash || !$this->payloadIsOffPartial($updated['payload'], '1,2,3')) {
            c31_fail('C_MANUAL_UPDATE', 'FORM_UPDATE_DID_NOT_CHANGE_ONLY_SYNTHETIC_DRAFT');
        }
        if ($this->databasePublicationState() !== $this->stateBeforePublish || $this->manifestSha !== $this->hashManifestOnDisk()) {
            c31_fail('C_MANUAL_UPDATE', 'MANUAL_FORM_CHANGED_PUBLISHED_POINTER_OR_MANIFEST');
        }
        if ((int) $this->db->scalar('SELECT COUNT(*) FROM restriction_rule_versions WHERE jurisdiction_id=?', [(int) $jurisdiction['id']]) !== 2) {
            c31_fail('C_MANUAL_UPDATE', 'EXPECTED_TWO_SYNTHETIC_DRAFTS_AFTER_MANUAL_FLOW');
        }
        $this->manualDraftId = $draftId;
        c31_log('C_MANUAL_UPDATE', 'PASS draft_id='.$draftId.' payload_sha256_before='.$beforeHash.' payload_sha256_after='.$updated['payload_sha256'].' published_version_unchanged='.$published['version']);
    }

    private function payloadIsOffPartial(string $json, string $digits): bool
    {
        $payload = json_decode($json, true);
        $coverage = $payload['coverages'][0] ?? null;
        $rule = $coverage['rules'][0] ?? null;

        return is_array($payload) && ($payload['id'] ?? null) === 'c31-synthetic-off'
            && ($payload['consultationEnabled'] ?? null) === false
            && is_array($coverage) && ($coverage['consultationEnabled'] ?? null) === false
            && ($coverage['coverageCompleteness'] ?? null) === 'partial'
            && is_array($rule) && implode(',', $rule['digits'] ?? []) === $digits
            && count($coverage['rules'] ?? []) === 1;
    }

    private function databasePublicationState(): array
    {
        $dataset = $this->db->one("SELECT id, current_version, publication_revision FROM datasets WHERE key='restrictions'");
        if (! $dataset) {
            c31_fail('C_STATE', 'RESTRICTIONS_DATASET_MISSING');
        }

        return [
            'current_version' => $dataset['current_version'],
            'publication_revision' => (int) $dataset['publication_revision'],
            'release_count' => (int) $this->db->scalar('SELECT COUNT(*) FROM dataset_releases WHERE dataset_id=?', [(int) $dataset['id']]),
            'publication_count' => (int) $this->db->scalar('SELECT COUNT(*) FROM restriction_publications rp JOIN dataset_releases dr ON dr.id=rp.dataset_release_id WHERE dr.dataset_id=?', [(int) $dataset['id']]),
            'version' => $dataset['current_version'],
            'sha256' => (string) ($this->db->scalar('SELECT sha256 FROM dataset_releases WHERE dataset_id=? AND version=?', [(int) $dataset['id'], (string) $dataset['current_version']]) ?: ''),
            'asset_path' => (string) ($this->db->scalar('SELECT asset_path FROM dataset_releases WHERE dataset_id=? AND version=?', [(int) $dataset['id'], (string) $dataset['current_version']]) ?: ''),
        ];
    }

    private function hashManifestOnDisk(): string
    {
        $path = $this->publicRoot.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1'.DIRECTORY_SEPARATOR.'manifest.json';
        $bytes = is_file($path) ? file_get_contents($path) : false;
        if (! is_string($bytes)) {
            c31_fail('C_MANUAL_UPDATE', 'MANIFEST_STORAGE_MISSING_AFTER_FORM_UPDATE');
        }

        return hash('sha256', $bytes);
    }

    private function expectStatus(string $stage, array $response, array $allowed): void
    {
        if (! in_array($response['status'], $allowed, true)) {
            c31_fail($stage, 'HTTP_STATUS_'.$response['status'].'_UNEXPECTED');
        }
    }

    private function redirectLocation(string $stage, array $response, string $expectedPattern): string
    {
        if (! in_array($response['status'], [302, 303], true)) {
            c31_fail($stage, 'EXPECTED_REDIRECT_STATUS_GOT_'.$response['status']);
        }
        $location = (string) ($response['headers']['location'] ?? '');
        try {
            $path = c31_local_redirect_path($this->origin, $location);
        } catch (Throwable) {
            c31_fail($stage, 'REDIRECT_DESTINATION_NOT_LOCAL');
        }
        if (preg_match($expectedPattern, $path) !== 1) {
            c31_fail($stage, 'REDIRECT_DESTINATION_NOT_EXPECTED_LOCAL_ROUTE');
        }

        return $path;
    }
}

if (PHP_SAPI === 'cli' && isset($_SERVER['SCRIPT_FILENAME']) && realpath($_SERVER['SCRIPT_FILENAME']) === __FILE__) {
    try {
        $mode = $argv[1] ?? '';
        if (! in_array($mode, ['--run', '--resume-confirmed'], true)) {
            fwrite(STDERR, "Usage: php editorial.php --run|--resume-confirmed\n");
            exit(64);
        }
        $workflow = new C31EditorialWorkflow;
        if ($mode === '--run') {
            $workflow->run();
        } else {
            $workflow->resumeConfirmed();
        }
        c31_log('C_HTTP', 'PASS_SCOPED_LIVE_EDITOR_HTTP');
    } catch (C31EditorialFailure $error) {
        c31_log($error->stage, 'BLOCKED '.$error->reason);
        exit(2);
    } catch (Throwable $error) {
        c31_log('C_RUNNER', 'BLOCKED class='.get_class($error).' message='.c31_safe_exception($error).' file='.basename($error->getFile()).' line='.$error->getLine());
        exit(2);
    }
}

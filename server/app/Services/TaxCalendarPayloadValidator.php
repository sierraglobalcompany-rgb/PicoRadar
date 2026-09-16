<?php

namespace App\Services;

use DomainException;

final class TaxCalendarPayloadValidator
{
    public function validate(array $payload): void
    {
        if (($payload['schemaVersion'] ?? null) !== 1 || ($payload['datasetKey'] ?? null) !== 'tax_calendars') {
            throw new DomainException('Unsupported tax calendar contract.');
        }
        $this->text($payload['version'] ?? null, 'version');
        $this->instant($payload['generatedAt'] ?? null, 'generatedAt');

        $authorityIds = [];
        $territories = [];
        foreach ($this->list($payload['authorities'] ?? null, 'authorities') as $value) {
            $authority = $this->object($value, 'authority');
            $this->unique($authorityIds, $this->text($authority['id'] ?? null, 'authority.id'), 'authority.id');
            $territory = $this->text($authority['territoryCode'] ?? null, 'territoryCode');
            if (! preg_match('/^[0-9]{2}$/D', $territory)) {
                throw new DomainException('territoryCode must be a two-digit DANE code.');
            }
            $this->unique($territories, $territory, 'territoryCode');
            $this->text($authority['territoryName'] ?? null, 'territoryName');
            $this->text($authority['name'] ?? null, 'authority.name');
            foreach (['institutionalUrl', 'portalUrl'] as $key) {
                if (($authority[$key] ?? null) !== null) {
                    $this->url($authority[$key]);
                }
            }
            $this->sources($authority['sourceUrls'] ?? null, true);
            $this->nullableInstant($authority['reviewedAt'] ?? null, 'authority.reviewedAt');
        }

        $calendarIds = [];
        $calendarKeys = [];
        foreach ($this->list($payload['calendars'] ?? null, 'calendars') as $value) {
            $calendar = $this->object($value, 'calendar');
            $this->unique($calendarIds, $this->text($calendar['id'] ?? null, 'calendar.id'), 'calendar.id');
            $authorityId = $this->text($calendar['authorityId'] ?? null, 'authorityId');
            if (! isset($authorityIds[$authorityId])) {
                throw new DomainException('Calendar authorityId must reference an authority in this payload.');
            }
            $year = $calendar['year'] ?? null;
            if (! is_int($year) || $year < 1 || $year > 9999) {
                throw new DomainException('Calendar year must be an integer civil year.');
            }
            $kind = $this->enum($calendar['obligationKind'] ?? null, ['vehicle_tax', 'semaforizacion', 'sistematizacion'], 'obligationKind');
            $this->unique($calendarKeys, json_encode([$authorityId, $year, $kind], JSON_THROW_ON_ERROR), 'calendar key');
            $status = $this->enum($calendar['status'] ?? null, ['verified', 'partial', 'pending', 'withdrawn'], 'calendar.status');
            $events = $this->list($calendar['events'] ?? null, 'events');
            $requiresEvidence = in_array($status, ['verified', 'partial'], true) && $events !== [];
            if ($requiresEvidence) {
                $this->instant($calendar['reviewedAt'] ?? null, 'calendar.reviewedAt');
            } else {
                $this->nullableInstant($calendar['reviewedAt'] ?? null, 'calendar.reviewedAt');
            }
            $this->nullableInstant($calendar['reviewAfter'] ?? null, 'reviewAfter');
            $this->sources($calendar['sourceUrls'] ?? null, $requiresEvidence);
            $this->events($events, $year, $status);
        }
    }

    private function events(array $events, int $year, string $calendarStatus): void
    {
        $ids = [];
        $replacements = [];
        foreach ($events as $value) {
            $event = $this->object($value, 'event');
            $id = $this->text($event['id'] ?? null, 'event.id');
            $this->unique($ids, $id, 'event.id');
            $date = $this->text($event['date'] ?? null, 'event.date');
            $this->civilDate($date);
            $this->text($event['label'] ?? null, 'event.label');
            $kind = $this->enum($event['kind'] ?? null, ['discount', 'ordinary', 'installmentEnrollment', 'installment'], 'event.kind');
            $condition = $event['condition'] ?? null;
            if ($condition !== null || in_array($kind, ['installmentEnrollment', 'installment'], true)) {
                $this->text($condition, 'event.condition');
            }
            $dateYear = (int) substr($date, 0, 4);
            if ($dateYear !== $year && ($dateYear !== $year + 1 || $condition === null)) {
                throw new DomainException('Event date must belong to the tax year or the following year with an explicit condition.');
            }
            $status = $this->enum($event['status'] ?? null, ['active', 'superseded', 'withdrawn'], 'event.status');
            if ($status === 'active' && in_array($calendarStatus, ['pending', 'withdrawn'], true)) {
                throw new DomainException('Pending or withdrawn calendars cannot contain active events.');
            }
            $replacement = $event['supersededBy'] ?? null;
            if ($status === 'superseded') {
                $replacements[$id] = $this->text($replacement, 'supersededBy');
            } elseif ($replacement !== null) {
                throw new DomainException('Only superseded events may reference a replacement.');
            }
            $this->sources($event['sourceUrls'] ?? null, true);
        }

        foreach ($replacements as $replacement) {
            if (! isset($ids[$replacement])) {
                throw new DomainException('supersededBy must reference an event in the same calendar.');
            }
        }
        // Walk each replacement chain once, including retained historical events.
        $checked = [];
        foreach ($replacements as $id => $replacement) {
            $path = [];
            while (isset($replacements[$id]) && ! isset($checked[$id])) {
                if (isset($path[$id])) {
                    throw new DomainException('Event supersession must not contain cycles.');
                }
                $path[$id] = true;
                $id = $replacements[$id];
            }
            $checked += $path;
        }
    }

    private function text(mixed $value, string $field): string
    {
        if (! is_string($value) || trim($value) === '') {
            throw new DomainException("$field must be nonempty text.");
        }

        return $value;
    }

    private function enum(mixed $value, array $allowed, string $field): string
    {
        if (! in_array($value, $allowed, true)) {
            throw new DomainException("$field has an unsupported value.");
        }

        return $value;
    }

    private function list(mixed $value, string $field): array
    {
        if (! is_array($value) || ! array_is_list($value)) {
            throw new DomainException("$field must be a list.");
        }

        return $value;
    }

    private function object(mixed $value, string $field): array
    {
        // Preserve JSON objects at list boundaries so {} cannot masquerade as [].
        if ($value instanceof \stdClass) {
            $value = (array) $value;
        }
        if (! is_array($value) || array_is_list($value)) {
            throw new DomainException("$field must be an object.");
        }

        return $value;
    }

    private function unique(array &$seen, string $id, string $field): void
    {
        if (isset($seen[$id])) {
            throw new DomainException("Duplicate $field.");
        }
        $seen[$id] = true;
    }

    private function civilDate(string $value): void
    {
        if (! preg_match('/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/D', $value, $parts)
            || ! checkdate((int) $parts[2], (int) $parts[3], (int) $parts[1])) {
            throw new DomainException('Event date must be a real YYYY-MM-DD civil date.');
        }
    }

    private function nullableInstant(mixed $value, string $field): void
    {
        if ($value !== null) {
            $this->instant($value, $field);
        }
    }

    private function instant(mixed $value, string $field): void
    {
        if (! is_string($value)
            || ! preg_match('/^([0-9]{4})-([0-9]{2})-([0-9]{2})T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:\.[0-9]+)?(?:Z|[+-](?:[01][0-9]|2[0-3]):[0-5][0-9])$/D', $value, $parts)
            || ! checkdate((int) $parts[2], (int) $parts[3], (int) $parts[1])) {
            throw new DomainException("$field must be a real ISO-8601 instant with a timezone.");
        }
    }

    private function sources(mixed $value, bool $required): void
    {
        $urls = $this->list($value, 'sourceUrls');
        if ($required && $urls === []) {
            throw new DomainException('Nonempty sourceUrls are required for tax evidence.');
        }
        foreach ($urls as $url) {
            $this->url($url);
        }
    }

    private function url(mixed $value): void
    {
        if (! is_string($value) || preg_match('/[\s\\\\\x00-\x1f\x7f]/', $value) || filter_var($value, FILTER_VALIDATE_URL) === false) {
            throw new DomainException('Tax links must be safe public HTTPS URLs.');
        }
        $parts = parse_url($value);
        $host = strtolower($parts['host'] ?? '');
        $labels = explode('.', $host);
        $suffix = end($labels);
        if (strtolower($parts['scheme'] ?? '') !== 'https' || isset($parts['user']) || isset($parts['pass'])
            || strlen($host) > 253 || count($labels) < 2 || ! preg_match('/^[a-z]{2,63}$/D', $suffix)
            || in_array($suffix, ['localhost', 'local', 'internal', 'lan', 'home', 'test', 'invalid', 'onion'], true)) {
            throw new DomainException('Tax links must use a public HTTPS hostname without credentials or IP literals.');
        }
        foreach ($labels as $label) {
            if (! preg_match('/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/D', $label)) {
                throw new DomainException('Tax link hostname is invalid.');
            }
        }
        // Inspect decoded names, including bracketed parameters, without logging URLs.
        $personalParameters = [
            'placa', 'placavehiculo', 'plate', 'licenseplate', 'vehicleplate',
            'cedula', 'numerocedula', 'document', 'documento', 'numerodocumento', 'documentnumber', 'doc', 'dni', 'nit',
            'identificacion', 'numeroidentificacion', 'identification', 'idnumber',
            'email', 'correo', 'correoelectronico', 'telefono', 'phone', 'phonenumber',
            'password', 'contrasena', 'token', 'accesstoken', 'vin', 'chasis',
        ];
        foreach (preg_split('/[&;]/', $parts['query'] ?? '') as $parameter) {
            $name = strtolower(str_replace(["\u{00e9}", "\u{00c9}"], 'e', urldecode(explode('=', $parameter, 2)[0])));
            foreach (preg_split('/[\[\].]/', $name) as $segment) {
                $key = preg_replace('/[^a-z0-9]/', '', $segment);
                if (in_array($key, $personalParameters, true)) {
                    throw new DomainException('Tax links must not contain personal or secret query parameters.');
                }
            }
        }
    }
}

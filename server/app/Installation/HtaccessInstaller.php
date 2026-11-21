<?php

namespace App\Installation;

use RuntimeException;

class HtaccessInstaller
{
    public const START_MARKER = '# BEGIN PICORADAR ROUTING';

    public const END_MARKER = '# END PICORADAR ROUTING';

    public function install(string $targetPath, string $templatePath): void
    {
        if (! is_file($templatePath)) {
            throw new RuntimeException('The routing template is unavailable.');
        }

        $routing = trim((string) file_get_contents($templatePath));
        if ($routing === '') {
            throw new RuntimeException('The routing template is empty.');
        }

        $existing = is_file($targetPath) ? (string) file_get_contents($targetPath) : '';
        $pattern = '/'.preg_quote(self::START_MARKER, '/').'.*?'.preg_quote(self::END_MARKER, '/').'/s';
        $block = self::START_MARKER.PHP_EOL.$routing.PHP_EOL.self::END_MARKER;
        $contents = preg_match($pattern, $existing) === 1
            ? (string) preg_replace($pattern, $block, $existing, 1)
            : rtrim($existing).($existing === '' ? '' : PHP_EOL.PHP_EOL).$block.PHP_EOL;

        (new AtomicFileWriter)->write($targetPath, $contents);
        @chmod($targetPath, 0644);
    }
}

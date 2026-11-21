<?php

namespace App\Services;

use DomainException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class CampaignImageStore
{
    /** @return array{source_image_path:string,image_sha256:string,image_mime:string,image_width:int,image_height:int,image_bytes:int} */
    public function store(UploadedFile $file, string $campaignId): array
    {
        $path = $file->getRealPath();
        $bytes = $file->getSize();
        $dimensions = $path ? @getimagesize($path) : false;
        $mime = $path ? (new \finfo(FILEINFO_MIME_TYPE))->file($path) : false;
        $allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
        if (! is_array($dimensions) || ! is_string($mime) || ! isset($allowed[$mime])) {
            throw new DomainException('Campaign image bytes must be JPEG, PNG, or WebP.');
        }
        [$width, $height] = $dimensions;
        if ($bytes === false || $bytes <= 0 || $bytes > config('campaigns.max_image_bytes')) {
            throw new DomainException('Campaign image size is outside the allowed limit.');
        }
        if ($width < config('campaigns.min_image_width') || $height < config('campaigns.min_image_height') || $width > config('campaigns.max_image_width') || $height > config('campaigns.max_image_height')) {
            throw new DomainException('Campaign image dimensions are outside the C11-safe range.');
        }
        $ratio = $width / $height;
        if ($ratio < config('campaigns.min_image_aspect_ratio') || $ratio > config('campaigns.max_image_aspect_ratio')) {
            throw new DomainException('Campaign image aspect ratio must fit the C11 carousel.');
        }
        $content = $file->getContent();
        $sha = hash('sha256', $content);
        $sourcePath = "campaign-images/{$campaignId}/source/{$sha}.{$allowed[$mime]}";
        if (Storage::disk(config('campaigns.private_disk'))->put($sourcePath, $content) === false) {
            throw new DomainException('Campaign image could not be stored privately.');
        }

        return [
            'source_image_path' => $sourcePath,
            'image_sha256' => $sha,
            'image_mime' => $mime,
            'image_width' => $width,
            'image_height' => $height,
            'image_bytes' => $bytes,
        ];
    }

    public function duplicate(string $sourcePath, string $campaignId): string
    {
        $disk = Storage::disk(config('campaigns.private_disk'));
        if (! $disk->exists($sourcePath)) {
            throw new DomainException('Campaign source image is unavailable.');
        }
        $target = "campaign-images/{$campaignId}/source/".basename($sourcePath);
        if ($disk->put($target, $disk->get($sourcePath)) === false) {
            throw new DomainException('Campaign image could not be duplicated.');
        }

        return $target;
    }

    public function promote(string $sourcePath, string $sha256, string $mime): string
    {
        $private = Storage::disk(config('campaigns.private_disk'));
        $public = Storage::disk(config('campaigns.public_disk'));
        if (! $private->exists($sourcePath)) {
            throw new DomainException('Campaign source image is unavailable.');
        }
        $bytes = $private->get($sourcePath);
        if (! hash_equals($sha256, hash('sha256', $bytes))) {
            throw new DomainException('Campaign source image changed after validation.');
        }
        $extension = match ($mime) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            default => throw new DomainException('Campaign image type is not publishable.'),
        };
        $path = "campaigns/assets/{$sha256}.{$extension}";
        if ($public->exists($path)) {
            if (! hash_equals($sha256, hash('sha256', $public->get($path)))) {
                throw new DomainException('Published campaign image is corrupt.');
            }
        } elseif ($public->put($path, $bytes) === false || ! hash_equals($sha256, hash('sha256', $public->get($path)))) {
            throw new DomainException('Published campaign image verification failed.');
        }

        return $path;
    }
}

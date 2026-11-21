<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;

class CampaignCatalogController extends Controller
{
    public function __invoke(Request $request): Response
    {
        // API visibility is independent of staff access to drafts and history.
        if (config('campaigns.public_catalog_enabled') !== true) {
            return response(['message' => 'Campaign catalog is not available.'], 404);
        }

        $disk = Storage::disk(config('campaigns.public_disk'));
        $path = config('campaigns.catalog_manifest_path');
        if (! $disk->exists($path)) {
            return response(['message' => 'Campaign catalog is not available.'], 404);
        }

        $bytes = $disk->get($path);
        $etag = '"'.hash('sha256', $bytes).'"';
        $headers = [
            'Cache-Control' => 'public, max-age='.config('campaigns.cache_ttl_seconds'),
            'ETag' => $etag,
        ];
        if ($request->headers->get('If-None-Match') === $etag) {
            return response('', 304, $headers);
        }

        return response($bytes, 200, $headers + ['Content-Type' => 'application/json']);
    }
}

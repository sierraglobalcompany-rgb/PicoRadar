<?php

namespace Database\Factories;

use App\Enums\CameraVerificationDecision;
use App\Models\CameraVerification;
use Illuminate\Database\Eloquent\Factories\Factory;

class CameraVerificationFactory extends Factory
{
    protected $model = CameraVerification::class;

    public function definition(): array
    {
        return ['decision' => CameraVerificationDecision::Verified, 'fingerprint' => hash('sha256', $this->faker->uuid()), 'source_url_snapshot' => 'https://example.test/synthetic', 'speed_limit_verified' => false];
    }
}

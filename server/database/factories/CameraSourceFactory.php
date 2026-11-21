<?php

namespace Database\Factories;

use App\Enums\CameraSourceType;
use App\Models\CameraSource;
use Illuminate\Database\Eloquent\Factories\Factory;

class CameraSourceFactory extends Factory
{
    protected $model = CameraSource::class;

    public function definition(): array
    {
        return ['key' => 'synthetic-'.$this->faker->unique()->slug(2), 'title' => 'Synthetic source', 'authority' => 'Synthetic authority', 'url' => 'https://example.test/'.$this->faker->unique()->slug(), 'source_type' => CameraSourceType::Reference, 'is_active' => true, 'verified_at' => now()];
    }
}

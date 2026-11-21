<?php

namespace Database\Factories;

use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Models\Camera;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class CameraFactory extends Factory
{
    protected $model = Camera::class;

    public function definition(): array
    {
        return ['camera_id' => 'cam_'.strtolower((string) Str::ulid()), 'external_id' => $this->faker->unique()->uuid(), 'name' => 'Synthetic Camera '.$this->faker->lexify('??'), 'lat' => 4.7110000, 'lon' => -74.0721000, 'type' => CameraType::Other, 'status' => CameraStatus::Draft, 'speed_limit_verified' => false];
    }

    public function draft(): static
    {
        return $this->state(['status' => CameraStatus::Draft]);
    }

    public function inReview(): static
    {
        return $this->state(['status' => CameraStatus::InReview, 'submitted_at' => now()]);
    }

    public function verified(): static
    {
        return $this->state(['status' => CameraStatus::Verified, 'verified_at' => now(), 'verification_fingerprint' => str_repeat('a', 64)]);
    }

    public function active(): static
    {
        return $this->verified()->state(['status' => CameraStatus::Active]);
    }

    public function inactive(): static
    {
        return $this->verified()->state(['status' => CameraStatus::Inactive]);
    }

    public function retired(): static
    {
        return $this->state(['status' => CameraStatus::Retired, 'retired_at' => now()]);
    }

    public function speedCamera(): static
    {
        return $this->state(['type' => CameraType::Speed, 'speed_limit' => 50]);
    }
}

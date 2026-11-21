<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_users', function (Blueprint $table): void {
            $table->id();
            $table->uuid('public_id')->unique();
            $table->string('name', 120)->nullable();
            $table->string('email', 254)->unique();
            $table->string('phone', 24)->nullable();
            $table->string('municipality', 120)->nullable();
            $table->json('categories')->nullable();
            $table->string('privacy_version', 40);
            $table->timestamp('privacy_accepted_at');
            $table->string('privacy_purpose', 40)->default('optional_account');
            $table->boolean('marketing_consent')->default(false);
            $table->string('marketing_version', 40)->nullable();
            $table->timestamp('marketing_consented_at')->nullable();
            $table->timestamp('email_verified_at')->nullable();
            $table->timestamps();
            $table->index(['marketing_consent', 'email_verified_at']);
            $table->index(['municipality', 'created_at']);
        });

        Schema::create('app_login_challenges', function (Blueprint $table): void {
            $table->id();
            $table->string('email', 254)->unique();
            $table->string('otp_hash', 255);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->string('privacy_version', 40)->nullable();
            $table->timestamp('privacy_accepted_at')->nullable();
            $table->timestamp('expires_at')->index();
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
            $table->index(['consumed_at', 'expires_at']);
        });

        Schema::create('app_access_tokens', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('app_user_id')->nullable()->constrained('app_users')->cascadeOnDelete();
            $table->string('purpose', 16)->index();
            $table->char('token_hash', 64)->unique();
            $table->timestamp('expires_at')->index();
            $table->timestamp('used_at')->nullable();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();
            $table->index(['app_user_id', 'purpose', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_access_tokens');
        Schema::dropIfExists('app_login_challenges');
        Schema::dropIfExists('app_users');
    }
};
